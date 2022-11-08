# --- cluster/variables.tf ---

variable "tags" {
  description = "aws-tags"
}
variable "k8s_version" {
}
variable "desired_size" {
  type = number
}

variable "max_size" {
  type = number
}

variable "min_size" {
  type = number
}
variable "vpc_id" {}

variable "public_subnets" {}

variable "private_subnets" {}