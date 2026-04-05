project_id = "project-d25d1c66-5ac7-43e4-974"
env        = "dev"
region     = "us-central1"

topic_name        = "payment-events"
subscription_name = "payment-events-sub"

dataflow_job_name = "payment-pubsub-to-bq"
template_version  = "latest"

dataset_name = "payment_analytics"
table_name   = "payment_events"

dataflow_bucket_prefix = "dataflow"

use_storage_write_api               = false
use_storage_write_api_at_least_once = false