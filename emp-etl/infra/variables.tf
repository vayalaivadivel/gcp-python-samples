variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "env" {
  description = "Environment (dev/prod)"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "asia-south1"
}

# Cloud Function
variable "function_name" {
  default = "etl-function"
}

variable "function_runtime" {
  default = "python311"
}

# MySQL
variable "mysql_db" {
  default = "etl_db"
}

variable "mysql_user" {
  default = "etl_user"
}

variable "mysql_password" {
  description = "MySQL password"
  type        = string
  sensitive   = true
}

variable "my_ip" {
  
}