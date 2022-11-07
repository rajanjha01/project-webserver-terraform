##S3 BUCKET TO STORE THE SCRIPTS USED BY FRONTEND/BACKEND ASG 

module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket        = var.bucket_name
  acl    = "private"
  versioning = {
    enabled = true
  }
  force_destroy = true
}
## COPY THE INSTALLATION SCRIPTS TO S3 BUCKET - To be used by the web and app servers

resource "aws_s3_bucket_object" "web-object" {
for_each = fileset("source/", "*")
bucket = module.s3_bucket.s3_bucket_id
key = each.value
source = "source/${each.value}"
etag = filemd5("source/${each.value}")
}

###############################################################
