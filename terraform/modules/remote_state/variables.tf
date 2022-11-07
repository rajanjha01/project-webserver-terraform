variable "resource_prefix" {}
variable "aws_region" {

}
locals {
  bucket_name = "${var.resource_prefix}-infra-tfstate"
}