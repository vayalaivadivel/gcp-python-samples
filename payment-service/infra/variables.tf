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
  default     = "us-central1"
}

# Cloud Function
variable "function_name" {
  description = "Cloud Function name"
  type        = string
  default     = "etl-function"
}

variable "function_runtime" {
  description = "Cloud Function runtime"
  type        = string
  default     = "python311"
}

# MySQL
variable "mysql_db" {
  description = "MySQL database name"
  type        = string
  default     = "etl_db"
}

variable "mysql_user" {
  description = "MySQL username"
  type        = string
  default     = "etl_user"
}

variable "mysql_password" {
  description = "MySQL password"
  type        = string
  sensitive   = true
}

# Pub/Sub
variable "topic_name" {
  type        = string
  description = "Base Pub/Sub topic name"
  default     = "payment-events"
}

variable "subscription_name" {
  type        = string
  description = "Base Pub/Sub subscription name"
  default     = "payment-events-sub"
}

# Dataflow
variable "dataflow_job_name" {
  description = "Base Dataflow job name"
  type        = string
  default     = "payment-pubsub-to-bq"
}

variable "template_version" {
  description = "Dataflow template version"
  type        = string
  default     = "latest"
}

variable "use_storage_write_api" {
  description = "Use BigQuery Storage Write API"
  type        = bool
  default     = false
}

variable "use_storage_write_api_at_least_once" {
  description = "Use Storage Write API in at-least-once mode"
  type        = bool
  default     = false
}

# BigQuery
variable "dataset_name" {
  description = "Base BigQuery dataset name"
  type        = string
  default     = "payment_analytics"
}

variable "table_name" {
  description = "BigQuery table name"
  type        = string
  default     = "payment_events"
}

# GCS
variable "dataflow_bucket_prefix" {
  description = "Prefix for Dataflow temp bucket"
  type        = string
  default     = "dataflow"
}