# There are three variables declared in this file.
variable "project_id" {
  description = "healthconnect-project"
  type        = string
}

variable "region" {
  default = "us-central1"
}

variable "vpc_name" {
  default = "healthconnect-vpc-prod"
}