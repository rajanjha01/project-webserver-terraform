## CREATING RESOURCES FROM DEFINED MODULES

#LOCALS REFERRING TO THE CURRENT WORKING DIRECTORY

locals {
  cwd           = reverse(split("/", path.cwd))
  instance_type = local.cwd[1]
  location      = local.cwd[2]
  environment   = local.cwd[3]
  vpc_cidr      = "10.123.0.0/16"
}
## data block to get the master RDS password

data "aws_secretsmanager_secret" "password" {
  name = "web-db-password"

}

data "aws_secretsmanager_secret_version" "password" {
  secret_id = data.aws_secretsmanager_secret.password.id
}
## CREATING VPC, SUBNETS, NAT, IG AND SECURITY GROUPS

module "networking" {
  source            = "./modules/networking"
  vpc_cidr          = local.vpc_cidr
  access_ip         = var.access_ip
  public_sn_count   = 2
  private_sn_count  = 2
  db_subnet_group   = true
  availabilityzone  = "us-east-1a"
  azs               = 2
} 
## CREATING FRONTEND AND BACKEND SERVERS BEHIND AUTO SCALING GROUPS

module "servers" {
  source                  = "./modules/servers"
  bastion_sg              = module.networking.bastion_sg
  frontend_app_sg         = module.networking.frontend_app_sg
  backend_app_sg          = module.networking.backend_app_sg
  public_subnets          = module.networking.public_subnets
  private_subnets         = module.networking.private_subnets
  bastion_instance_count  = 1
  instance_type           = local.instance_type
  lb_tg_name              = module.loadbalancing.lb_tg_name
  lb_tg                   = module.loadbalancing.lb_tg
}

## CREATING DATABASE

module "database" {
  source               = "./modules/database"
  db_storage           = 20
  db_engine_version    = "12.5"
  db_instance_class    = "db.t2.micro"
  db_name              = var.db_name
  dbuser               = var.dbuser
  dbpassword           = data.aws_secretsmanager_secret_version.password
  db_identifier        = "web-db"
  skip_db_snapshot     = true
  rds_sg               = module.networking.rds_sg
  db_subnet_group_name = module.networking.db_subnet_group_name[0]
}

## CREATING LOAD BALANCER IN PUBLIC SUBNET
module "loadbalancing" {
  source                  = "./modules/lb"
  lb_sg                   = module.networking.lb_sg
  public_subnets          = module.networking.public_subnets
  tg_port                 = 80
  tg_protocol             = "HTTP"
  vpc_id                  = module.networking.vpc_id
  app_asg                 = module.servers.app_asg
  listener_port           = 80
  listener_protocol       = "HTTP"
  azs                     = 2
}
####################################################################
