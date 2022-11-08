## S3 as remote backend with dynamo for tfstate locking
terraform {
backend "local" {
  
}
/*
  backend "s3" {
    key            = "web/infra/terraform.tfstate"
    bucket         = "web-infra-tfstate"
    dynamodb_table = "web-infra-tfstate-lock"
    region         = "us-east-1"
  }
*/
}
