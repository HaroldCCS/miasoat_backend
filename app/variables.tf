variable "aws_region" {
  default = "us-east-1"
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