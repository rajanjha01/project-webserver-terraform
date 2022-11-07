#########################################################################
## WEB (RUNNING APACHE IN FRONTEND) AND APPLICATION SERVER
## (RUNNING NODE JS IN BACKEND) IN PRIVATE SUBENT
#########################################################################

# Generates a secure private key and encodes it as PEM
resource "tls_private_key" "key_pair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
# Create the Key Pair
resource "aws_key_pair" "key_pair" {
  key_name   = "linux-key-pair"
  public_key = tls_private_key.key_pair.public_key_openssh
}
# Save file
resource "local_file" "ssh_key" {
  filename = "${aws_key_pair.key_pair.key_name}.pem"
  content  = tls_private_key.key_pair.private_key_pem
}

# LATEST AMI FROM SSM PARAMETER STORE

data "aws_ssm_parameter" "web-ami" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}
# LAUNCH TEMPLATES AND AUTOSCALING GROUPS FOR BASTION IN PUBLIC SUBNET

resource "aws_launch_template" "web_bastion" {
  name_prefix            = "web_bastion"
  instance_type          = var.instance_type
  image_id               = data.aws_ssm_parameter.web-ami.value
  vpc_security_group_ids = [var.bastion_sg]
  key_name               = aws_key_pair.key_pair.key_name

  tags = {
    Name = "web_bastion"
  }
}

resource "aws_autoscaling_group" "web_bastion" {
  name                = "web_bastion"
  vpc_zone_identifier = var.public_subnets
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1

  launch_template {
    id      = aws_launch_template.web_bastion.id
    version = "$Latest"
  }
}

# LAUNCH TEMPLATES AND AUTOSCALING GROUPS FOR WEB SERVER - FRONTEND

## Fetch the user data from s3 bucket to install apache on web server

data "aws_s3_bucket_object" "web-object" {
  bucket = "aws_s3_bucket.web_bucket.id"
  key    = "install_apache.sh"
}

resource "aws_launch_template" "web_app" {
  name_prefix            = "web_app"
  instance_type          = var.instance_type
  image_id               = data.aws_ssm_parameter.web-ami.value
  vpc_security_group_ids = [var.frontend_app_sg]
  user_data              = data.aws_s3_bucket_object.web-object.body
  key_name               = aws_key_pair.key_pair.key_name

  tags = {
    Name = "web_app"
  }
}
## Fetch the load balancer target group
data "aws_lb_target_group" "web_tg" {
  name = var.lb_tg_name
}

## CREATING AUTOSCALING GROUP

resource "aws_autoscaling_group" "web_app" {
  name                = "web_app"
  vpc_zone_identifier = var.private_subnets
  min_size            = 2
  max_size            = 3
  desired_capacity    = 2

  target_group_arns = [data.aws_lb_target_group.web_tg.arn]

  launch_template {
    id      = aws_launch_template.web_app.id
    version = "$Latest"
  }
}

## LAUNCH TEMPLATES AND AUTOSCALING GROUPS FOR APPLICATION SERVER - BACKEND

## Fetch user data from s3 bucket for node.js installation on app server 

data "aws_s3_bucket_object" "app-object" {
  bucket = "aws_s3_bucket.web_bucket.id"
  key    = "install_node.sh"
}
resource "aws_launch_template" "web_backend" {
  name_prefix            = "web_backend"
  instance_type          = var.instance_type
  image_id               = data.aws_ssm_parameter.web-ami.value
  vpc_security_group_ids = [var.backend_app_sg]
  key_name               = aws_key_pair.key_pair.key_name
  user_data              = data.aws_s3_bucket_object.app-object.body

  tags = {
    Name = "web_backend"
  }
}

resource "aws_autoscaling_group" "web_backend" {
  name                = "web_backend"
  vpc_zone_identifier = var.private_subnets
  min_size            = 2
  max_size            = 3
  desired_capacity    = 2

  launch_template {
    id      = aws_launch_template.web_backend.id
    version = "$Latest"
  }
}

# AUTOSCALING ATTACHMENT FOR WEB SERVER TO LOADBALANCER

resource "aws_autoscaling_attachment" "asg_attach" {
  autoscaling_group_name = aws_autoscaling_group.web_app.id
  lb_target_group_arn    = var.lb_tg
}
##############################################################