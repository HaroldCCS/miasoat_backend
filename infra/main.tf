terraform {
  required_version = ">= 1.5.0"
  backend "s3" {
    bucket         = "misoat-terraform-state"
    key            = "infra/terraform.tfstate"
    region         = "us-east-1"
    use_lockfile   = true
    encrypt        = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

# --- DYNAMODB ---
resource "aws_dynamodb_table" "users_table" {
  name         = "UsersTable"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "placa"

  attribute {
    name = "placa"
    type = "S"
  }
}

# --- IAM SHARED ROLE ---
resource "aws_iam_role" "lambda_exec_shared" {
  name = "go_lambda_execution_role_shared_misoat"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "basic_exec" {
  role       = aws_iam_role.lambda_exec_shared.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "dynamo_crud_policy" {
  name = "LambdaDynamoCRUDPolicy_Misoat"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Scan",
        "dynamodb:Query"
      ]
      Effect   = "Allow"
      Resource = aws_dynamodb_table.users_table.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "dynamo_attach" {
  role       = aws_iam_role.lambda_exec_shared.name
  policy_arn = aws_iam_policy.dynamo_crud_policy.arn
}

# --- SQS QUEUES ---
resource "aws_sqs_queue" "queue_scrapping" {
  name                      = "queue-scrapping-misoat"
  message_retention_seconds = 86400
}

resource "aws_sqs_queue" "queue_send_email" {
  name                      = "queue-send-email-misoat"
  message_retention_seconds = 60 # Min TTL allowed by SQS is 60s
}

resource "aws_iam_policy" "sqs_policy" {
  name = "LambdaSQSPolicy_Misoat"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Effect   = "Allow"
        Resource = [
          aws_sqs_queue.queue_scrapping.arn,
          aws_sqs_queue.queue_send_email.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sqs_attach" {
  role       = aws_iam_role.lambda_exec_shared.name
  policy_arn = aws_iam_policy.sqs_policy.arn
}

# --- API GATEWAY ---
resource "aws_api_gateway_rest_api" "users_api" {
  name        = "Misoat-Users-API"
  description = "API para Misoat"
}

resource "aws_api_gateway_resource" "users_resource" {
  rest_api_id = aws_api_gateway_rest_api.users_api.id
  parent_id   = aws_api_gateway_rest_api.users_api.root_resource_id
  path_part   = "users"
}

resource "aws_api_gateway_method" "signup_method" {
  rest_api_id   = aws_api_gateway_rest_api.users_api.id
  resource_id   = aws_api_gateway_resource.users_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# Lambda integration uses constructed ARN instead of aws_lambda_function references
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.users_api.id
  resource_id             = aws_api_gateway_resource.users_resource.id
  http_method             = aws_api_gateway_method.signup_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:misoat_users_signup/invocations"
}

resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.users_api.id
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.users_resource.id,
      aws_api_gateway_method.signup_method.id,
      aws_api_gateway_integration.lambda_integration.id
    ]))
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.users_api.id
  stage_name    = "prod"
}

# Permission to invoke via API Gateway
resource "aws_lambda_permission" "apigw_signup" {
  statement_id  = "AllowAPIGatewayInvokeMisoatUsersSignUp"
  action        = "lambda:InvokeFunction"
  function_name = "misoat_users_signup"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.users_api.execution_arn}/*/*"
}

# --- EVENTBRIDGE SCHEDULER ---
resource "aws_iam_role" "eventbridge_role" {
  name = "eventbridge_scheduler_role_misoat"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "eventbridge_policy" {
  name   = "EventBridgeInvokeLambda_Misoat"
  role   = aws_iam_role.eventbridge_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = "lambda:InvokeFunction"
      Effect   = "Allow"
      Resource = "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:misoat_create_events"
    }]
  })
}

resource "aws_cloudwatch_event_rule" "scheduler" {
  name                = "misoat-daily-scheduler"
  schedule_expression = "cron(0 17 * * ? *)"
}

resource "aws_cloudwatch_event_target" "scheduler_target" {
  rule      = aws_cloudwatch_event_rule.scheduler.name
  target_id = "CreateEventsLambda"
  arn       = "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:misoat_create_events"
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch_Misoat"
  action        = "lambda:InvokeFunction"
  function_name = "misoat_create_events"
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scheduler.arn
}

output "api_gateway_url" {
  value = "${aws_api_gateway_stage.prod.invoke_url}/users"
}
