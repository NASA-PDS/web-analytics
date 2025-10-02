terraform {
  backend "s3" {
    bucket = "bucket-name"
    key    = "key_name/some_state.tfstate"
    region = "us-east-1"
  }
}
