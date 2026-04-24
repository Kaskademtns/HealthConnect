# There are three variables declared in this file.
variable "project_id" {
  description = "HealthConnect-Project"
  type        = string
}

variable "region" {
  default = "us-central1"
}

variable "vpc_name" {
  default = "healthconnect-vpc-prod"
}