terraform {
  backend "s3" {
    bucket = "pds-dev-gh01dc-infra"
    key    = "dev/pds_web_analytics.tfstate"
    region = "us-west-2"
  }
}
