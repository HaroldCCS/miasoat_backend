variable "aws_region" {
  default = "us-east-1"
}

variable "cors_allowed_origins" {
  description = "Comma-separated list of allowed CORS origins"
  type        = string
  default     = "http://localhost:8080"
}

variable "smtp_username" {
  type        = string
  description = "SMTP Username / From Address"
}

variable "smtp_password" {
  type        = string
  description = "SMTP Password"
  sensitive   = true
}