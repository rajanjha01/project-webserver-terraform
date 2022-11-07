## ROOT VARIABLES

variable "access_ip" {
  type = string
}

variable "db_name" {
  type = string
}

variable "dbuser" {
  type      = string
  sensitive = true
}
variable "bucket_name" {
  type = string
}
 
  