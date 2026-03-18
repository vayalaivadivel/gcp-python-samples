variable "project_id" {}
variable "region" {
  default = "us-central1"
}

variable "code_bucket_name" {}
variable "input_bucket_name" {}
variable "output_bucket_name" {}

variable "mysql_user" {
  default = "etl_user"
}

variable "mysql_password" {
  sensitive = true
}

variable "mysql_db" {
  default = "etl_db"
}

variable "function_name" {
  default = "etl-function"
}

variable "function_runtime" {
  default = "python310"
}