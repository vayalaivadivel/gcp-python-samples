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

variable "dataflow_bucket_prefix" {
  description = "Prefix for Dataflow temp bucket"
  type        = string
  default     = "dataflow"
}