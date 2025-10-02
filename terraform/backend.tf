terraform {
  backend "s3" {
    bucket = "pds-prod-gh01dc-infra"
    key    = "prod/pds_web_analytics.tfstate"
    region = "us-west-2"
  }
}
