variable "name" {
  default     = "tf-template"
  type        = string
  description = "Name of the VPC"
}

variable "project" {
  type        = string
  description = "Name of project this VPC is meant to house"
}

variable "environment" {
  type        = string
  description = "Name of environment this VPC is targeting"
}

variable "tags" {
  default     = {}
  type        = map(string)
  description = "Extra tags to attach to the VPC resources"
}


