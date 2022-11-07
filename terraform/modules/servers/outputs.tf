## AUTOSCALING GROUP AS FRONT/BACKEND 

output "app_asg" {
  value = aws_autoscaling_group.web_app
}

output "app_backend_asg" {
  value = aws_autoscaling_group.web_backend
}