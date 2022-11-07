## print the s3 bucket and dynamo db table id post tf changes in output

output "state_dynamo_db" {
  value       = aws_dynamodb_table.terraform_state_lock.id
  description = "Name of the remote state s3 bucket"
}

output "state_s3_bucket" {
  value       = aws_s3_bucket.terraform_state_bucket.id
  description = "Dynamo DB table for remote state"
}
