# terraform/main.tf

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Configure Docker provider for ECR
data "aws_caller_identity" "current" {}
data "aws_ecr_authorization_token" "token" {}

provider "docker" {
  registry_auth {
    address  = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
    username = data.aws_ecr_authorization_token.token.user_name
    password = data.aws_ecr_authorization_token.token.password
  }
}

########################################
# Variables
########################################
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "op1-finder"
}

variable "telegram_token" {
  description = "Telegram bot token"
  type        = string
  sensitive   = true
}

variable "telegram_chat_id" {
  description = "Telegram chat ID"
  type        = string
  sensitive   = true
}

variable "schedule_expression" {
  description = "EventBridge schedule expression"
  type        = string
  default     = "rate(2 hours)"
}

########################################
# Secrets Manager for API keys
########################################
resource "aws_secretsmanager_secret" "op1_finder_secrets" {
  name        = "${var.project_name}-secrets"
  description = "API keys and credentials for OP-1 finder"
  
  tags = {
    Project = var.project_name
  }
}

resource "aws_secretsmanager_secret_version" "op1_finder_secrets_v1" {
  secret_id     = aws_secretsmanager_secret.op1_finder_secrets.id
  secret_string = jsonencode({
    TELEGRAM_TOKEN   = var.telegram_token
    TELEGRAM_CHAT_ID = var.telegram_chat_id
  })
}

########################################
# IAM Role for Lambda
########################################
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "op1_finder_lambda_role" {
  name               = "${var.project_name}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Project = var.project_name
  }
}

# Basic Lambda execution
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.op1_finder_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Secrets Manager access
resource "aws_iam_role_policy" "lambda_secrets_access" {
  name = "${var.project_name}-lambda-secrets-access"
  role = aws_iam_role.op1_finder_lambda_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [aws_secretsmanager_secret.op1_finder_secrets.arn]
      }
    ]
  })
}

# Bedrock access for AI model. Too broad, must be refined.
resource "aws_iam_role_policy" "lambda_bedrock_access" {
  name = "${var.project_name}-lambda-bedrock-access"
  role = aws_iam_role.op1_finder_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["bedrock:*"]
        Resource = "*"
      }
    ]
  })
}

########################################
# ECR Repository for Lambda Image
########################################
resource "aws_ecr_repository" "op1_finder_image" {
  name = var.project_name

  tags = {
    Project = var.project_name
  }
}

# Build and push Docker image
resource "docker_image" "op1_finder" {
  name = "${aws_ecr_repository.op1_finder_image.repository_url}:latest"

  build {
    context    = "${path.module}/../src"
    dockerfile = "Dockerfile"
  }

  # Force rebuild on source changes
  triggers = {
    rebuild = filesha256("${path.module}/../src/handler.py")
  }
}

resource "docker_registry_image" "op1_finder" {
  name = docker_image.op1_finder.name
}

########################################
# Lambda Function
########################################
resource "aws_lambda_function" "op1_finder" {
  function_name = var.project_name
  role          = aws_iam_role.op1_finder_lambda_role.arn
  architectures = ["arm64"]

  package_type = "Image"
  image_uri    = docker_registry_image.op1_finder.name

  timeout     = 600  # 10 minutes
  memory_size = 512

  environment {
    variables = {
      SECRETS_ARN = aws_secretsmanager_secret.op1_finder_secrets.arn
    }
  }

  tags = {
    Project = var.project_name
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy.lambda_secrets_access,
    aws_iam_role_policy.lambda_bedrock_access,
  ]
}

########################################
# EventBridge for Scheduled Execution
########################################
resource "aws_cloudwatch_event_rule" "op1_finder_schedule" {
  name                = "${var.project_name}-schedule"
  description         = "Trigger OP-1 finder on schedule"
  schedule_expression = var.schedule_expression

  tags = {
    Project = var.project_name
  }
}

resource "aws_cloudwatch_event_target" "op1_finder_target" {
  rule      = aws_cloudwatch_event_rule.op1_finder_schedule.name
  target_id = "${var.project_name}-target"
  arn       = aws_lambda_function.op1_finder.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.op1_finder.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.op1_finder_schedule.arn
}

########################################
# Outputs
########################################
output "lambda_function_arn" {
  description = "ARN of the OP-1 finder Lambda function"
  value       = aws_lambda_function.op1_finder.arn
}

output "ecr_repository_url" {
  description = "ECR repository URL for Lambda images"
  value       = aws_ecr_repository.op1_finder_image.repository_url
}

output "secrets_manager_arn" {
  description = "ARN of the Secrets Manager secret"
  value       = aws_secretsmanager_secret.op1_finder_secrets.arn
}

output "schedule_rule_name" {
  description = "Name of the EventBridge schedule rule"
  value       = aws_cloudwatch_event_rule.op1_finder_schedule.name
} 