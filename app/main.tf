# --- CONFIGURACIÓN DE TERRAFORM ---
terraform {
  required_version = ">= 1.5.0"
  backend "s3" {
    bucket         = "deploy-lambdas-terraform-state"
    key            = "misoat/app/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock-table"
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

# --- DATA SOURCES ---
# Estos bloques permiten a este Terraform "leer" recursos creados por el de infra
data "aws_iam_role" "shared_role" { name = "go_lambda_execution_role_shared" }
data "aws_sqs_queue" "user_queue" { name = "user-creation-queue" }

# --- EMPAQUETADO ---
data "archive_file" "api_zip" {
  type        = "zip"
  source_file = "../dist_api/bootstrap" # Apunta al archivo llamado bootstrap
  output_path = "api_producer.zip"
}

data "archive_file" "worker_zip" {
  type        = "zip"
  source_file = "../dist_worker/bootstrap" # Apunta al archivo llamado bootstrap
  output_path = "worker_processor.zip"
}

# --- LAMBDAS ---

# 1. Producer API
resource "aws_lambda_function" "api_producer" {
  function_name    = var.lambda_producer_name
  filename         = data.archive_file.api_zip.output_path
  source_code_hash = data.archive_file.api_zip.output_base64sha256
  handler          = "bootstrap"
  runtime          = "provided.al2023"
  role             = data.aws_iam_role.shared_role.arn
  architectures    = ["arm64"]

  environment {
    variables = {
      TABLE_NAME = "UsersTable"
      SQS_URL    = data.aws_sqs_queue.user_queue.id
    }
  }
}

# 2. Worker SQS
resource "aws_lambda_function" "sqs_worker" {
  function_name    = var.lambda_worker_name 
  filename         = data.archive_file.worker_zip.output_path
  source_code_hash = data.archive_file.worker_zip.output_base64sha256
  handler          = "bootstrap"
  runtime          = "provided.al2023"
  role             = data.aws_iam_role.shared_role.arn
  architectures    = ["arm64"]

  environment {
    variables = {
      TABLE_NAME  = "UsersTable"
      MONGO_URI   = var.mongo_param_path
    }
  }
}

# --- TRIGGERS ---
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = data.aws_sqs_queue.user_queue.arn
  function_name    = aws_lambda_function.sqs_worker.arn
  batch_size       = 1
  scaling_config {
    maximum_concurrency = 2 #2 es el minimo por AWS
  }
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_producer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.aws_region}:${var.aws_account_id}:*/*/*"
}