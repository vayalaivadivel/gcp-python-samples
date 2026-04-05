output "pubsub_topic_name" {
  value = google_pubsub_topic.payment_events.name
}

output "pubsub_subscription_name" {
  value = google_pubsub_subscription.payment_events_sub.name
}

output "pubsub_topic_path" {
  value = local.input_topic_path
}

output "bigquery_dataset" {
  value = google_bigquery_dataset.payment_analytics.dataset_id
}

output "bigquery_table" {
  value = google_bigquery_table.payment_events.table_id
}

output "output_table_spec" {
  value = local.output_table_spec
}

output "dataflow_job_name" {
  value = google_dataflow_flex_template_job.pubsub_to_bigquery.name
}

output "dataflow_temp_bucket" {
  value = google_storage_bucket.dataflow_temp.name
}

output "dataflow_worker_service_account" {
  value = google_service_account.dataflow_worker.email
}