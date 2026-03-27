terraform {
  backend "gcs" {
    bucket  = "vadivel_terraform_buc"
    prefix  = "etl-project/dev"
  }
}