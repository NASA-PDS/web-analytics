terraform {
  backend "s3" {
    key = "web-analytics/iam-policies.tfstate"
  }
}
