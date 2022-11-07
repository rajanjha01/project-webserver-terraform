## DATABASE OUTPUT

output "db_endpoint" {
  value = aws_db_instance.web_db.endpoint
}