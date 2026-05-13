# --- CONFIGURACIÓN DE TERRAFORM ---
terraform {
  required_version = ">= 1.5.0"
  backend "s3" {
    bucket         = "misoat-terraform-state"
    key            = "app/terraform.tfstate"
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
data "aws_iam_role" "shared_role" { name = "go_lambda_execution_role_shared_misoat" }
data "aws_sqs_queue" "queue_scrapping" { name = "queue-scrapping-misoat" }
data "aws_sqs_queue" "queue_send_email" { name = "queue-send-email-misoat" }

# --- LAMBDAS ---
resource "aws_lambda_function" "users_signup" {
  filename         = "../bin/users_signup.zip"
  function_name    = "misoat_users_signup"
  role             = data.aws_iam_role.shared_role.arn
  handler          = "bootstrap"
  runtime          = "provided.al2023"
  source_code_hash = filebase64sha256("../bin/users_signup.zip")
}

resource "aws_lambda_function" "create_events" {
  filename         = "../bin/create_events.zip"
  function_name    = "misoat_create_events"
  role             = data.aws_iam_role.shared_role.arn
  handler          = "bootstrap"
  runtime          = "provided.al2023"
  source_code_hash = filebase64sha256("../bin/create_events.zip")
  
  environment {
    variables = {
      QUEUE_SCRAPPING_URL = data.aws_sqs_queue.queue_scrapping.url
    }
  }
}

resource "aws_lambda_function" "scrapping_per_user" {
  filename         = "../bin/scrapping_per_user.zip"
  function_name    = "misoat_scrapping_per_user"
  role             = data.aws_iam_role.shared_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  source_code_hash = filebase64sha256("../bin/scrapping_per_user.zip")

  environment {
    variables = {
      QUEUE_SEND_EMAIL_URL = data.aws_sqs_queue.queue_send_email.url
    }
  }
}

resource "aws_lambda_function" "send_email" {
  filename         = "../bin/send_email.zip"
  function_name    = "misoat_send_email"
  role             = data.aws_iam_role.shared_role.arn
  handler          = "bootstrap"
  runtime          = "provided.al2023"
  source_code_hash = filebase64sha256("../bin/send_email.zip")
}

# --- TRIGGERS / MAPPINGS ---
resource "aws_lambda_event_source_mapping" "scrapping_sqs_mapping" {
  event_source_arn = data.aws_sqs_queue.queue_scrapping.arn
  function_name    = aws_lambda_function.scrapping_per_user.arn
  batch_size       = 1
}

resource "aws_lambda_event_source_mapping" "send_email_sqs_mapping" {
  event_source_arn = data.aws_sqs_queue.queue_send_email.arn
  function_name    = aws_lambda_function.send_email.arn
  batch_size       = 1
}