variable "aws_region" {
  type = string
}

variable "aws_profile" {
  type = string
}

variable "alert_email" {
  type = map(string)
}
