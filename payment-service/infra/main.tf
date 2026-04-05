locals {
  topic_name        = "${var.topic_name}-${var.env}"
  subscription_name = "${var.subscription_name}-${var.env}"
  dataset_id        = "${var.dataset_name}_${var.env}"
  table_id          = var.table_name
  bucket_name       = "${var.project_id}-${var.dataflow_bucket_prefix}-${var.env}"
  full_job_name     = "${var.dataflow_job_name}-${var.env}"
  worker_sa_name    = "payment-dataflow-sa-${var.env}"

  output_table_spec = "${var.project_id}:${local.dataset_id}.${local.table_id}"
  input_topic_path  = "projects/${var.project_id}/topics/${local.topic_name}"
  temp_location     = "gs://${local.bucket_name}/tmp"
  template_path     = "gs://dataflow-templates-${var.region}/${var.template_version}/flex/PubSub_to_BigQuery_Flex"
}

#
# Enable required APIs
#
resource "google_project_service" "pubsub_api" {
  project            = var.project_id
  service            = "pubsub.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "bigquery_api" {
  project            = var.project_id
  service            = "bigquery.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "dataflow_api" {
  project            = var.project_id
  service            = "dataflow.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "storage_api" {
  project            = var.project_id
  service            = "storage.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "compute_api" {
  project            = var.project_id
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

#
# Pub/Sub Topic
#
resource "google_pubsub_topic" "payment_events" {
  name = local.topic_name

  depends_on = [
    google_project_service.pubsub_api
  ]
}

#
# Optional pull subscription
# Not required for Dataflow if using inputTopic, but keeping because you already have subscription_name variable
#
resource "google_pubsub_subscription" "payment_events_sub" {
  name  = local.subscription_name
  topic = google_pubsub_topic.payment_events.id

  ack_deadline_seconds = 20

  depends_on = [
    google_project_service.pubsub_api,
    google_pubsub_topic.payment_events
  ]
}

#
# BigQuery Dataset
#
resource "google_bigquery_dataset" "payment_analytics" {
  dataset_id                 = local.dataset_id
  location                   = var.region
  delete_contents_on_destroy = true

  depends_on = [
    google_project_service.bigquery_api
  ]
}

#
# BigQuery Table
#
resource "google_bigquery_table" "payment_events" {
  dataset_id          = google_bigquery_dataset.payment_analytics.dataset_id
  table_id            = local.table_id
  deletion_protection = false

  schema = jsonencode([
    {
      name = "eventType",
      type = "STRING",
      mode = "NULLABLE"
    },
    {
      name = "paymentId",
      type = "STRING",
      mode = "NULLABLE"
    },
    {
      name = "orderId",
      type = "STRING",
      mode = "NULLABLE"
    },
    {
      name = "customerId",
      type = "STRING",
      mode = "NULLABLE"
    },
    {
      name = "amount",
      type = "FLOAT",
      mode = "NULLABLE"
    },
    {
      name = "currency",
      type = "STRING",
      mode = "NULLABLE"
    },
    {
      name = "status",
      type = "STRING",
      mode = "NULLABLE"
    },
    {
      name = "createdAt",
      type = "TIMESTAMP",
      mode = "NULLABLE"
    }
  ])

  depends_on = [
    google_bigquery_dataset.payment_analytics
  ]
}

#
# GCS Bucket for Dataflow temp/staging
#
resource "google_storage_bucket" "dataflow_temp" {
  name                        = local.bucket_name
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true

  depends_on = [
    google_project_service.storage_api
  ]
}

#
# Dataflow Worker Service Account
#
resource "google_service_account" "dataflow_worker" {
  account_id   = local.worker_sa_name
  display_name = "Payment Dataflow Worker SA ${var.env}"
}

#
# IAM Roles for Dataflow Worker
#
resource "google_project_iam_member" "dataflow_worker_role" {
  project = var.project_id
  role    = "roles/dataflow.worker"
  member  = "serviceAccount:${google_service_account.dataflow_worker.email}"
}

resource "google_project_iam_member" "storage_object_admin_role" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.dataflow_worker.email}"
}

resource "google_project_iam_member" "bigquery_data_editor_role" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.dataflow_worker.email}"
}

resource "google_project_iam_member" "bigquery_job_user_role" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.dataflow_worker.email}"
}

resource "google_project_iam_member" "pubsub_subscriber_role" {
  project = var.project_id
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${google_service_account.dataflow_worker.email}"
}

resource "google_project_iam_member" "pubsub_viewer_role" {
  project = var.project_id
  role    = "roles/pubsub.viewer"
  member  = "serviceAccount:${google_service_account.dataflow_worker.email}"
}


resource "google_project_iam_member" "pubsub_editor_role" {
  project = var.project_id
  role    = "roles/pubsub.editor"
  member  = "serviceAccount:${google_service_account.dataflow_worker.email}"
}
#
# Dataflow Flex Template Job
#
resource "google_dataflow_flex_template_job" "pubsub_to_bigquery" {
  provider = google-beta

  name                    = local.full_job_name
  region                  = var.region
  container_spec_gcs_path = local.template_path
  temp_location           = local.temp_location
  service_account_email   = google_service_account.dataflow_worker.email
  on_delete               = "cancel"

  parameters = {
    inputTopic                    = local.input_topic_path
    outputTableSpec               = local.output_table_spec
    useStorageWriteApi            = tostring(var.use_storage_write_api)
    useStorageWriteApiAtLeastOnce = tostring(var.use_storage_write_api_at_least_once)
  }

  depends_on = [
    google_project_service.pubsub_api,
    google_project_service.bigquery_api,
    google_project_service.dataflow_api,
    google_project_service.storage_api,
    google_project_service.compute_api,
    google_pubsub_topic.payment_events,
    google_bigquery_table.payment_events,
    google_storage_bucket.dataflow_temp,
    google_project_iam_member.dataflow_worker_role,
    google_project_iam_member.storage_object_admin_role,
    google_project_iam_member.bigquery_data_editor_role,
    google_project_iam_member.bigquery_job_user_role,
    google_project_iam_member.pubsub_subscriber_role,
    google_project_iam_member.pubsub_viewer_role,
    google_project_iam_member.pubsub_editor_role
  ]
}