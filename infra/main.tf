###########################
# Enable required APIs
###########################
resource "google_project_service" "cloudfunctions_api" {
  project            = var.project_id
  service            = "cloudfunctions.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloudbuild_api" {
  project            = var.project_id
  service            = "cloudbuild.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "pubsub_api" {
  project            = var.project_id
  service            = "pubsub.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "secretmanager_api" {
  project            = var.project_id
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

###########################
# Buckets
###########################
resource "google_storage_bucket" "code_bucket" {
  name          = "${var.project_id}-function-code-${var.env}"
  location      = var.region
  force_destroy = true

  uniform_bucket_level_access = true

  labels = {
    env  = var.env
    type = "code"
  }
}

resource "google_storage_bucket" "input_bucket" {
  name          = "${var.project_id}-input-${var.env}"
  location      = var.region
  force_destroy = true

  uniform_bucket_level_access = true

  labels = {
    env  = var.env
    type = "input"
  }
}

###########################
# Cloud SQL: MySQL
###########################
resource "google_sql_database_instance" "mysql" {
  name             = "etl-emp-${var.env}"
  database_version = "MYSQL_8_0"
  region           = var.region

  deletion_protection = false

  settings {
    tier            = "db-f1-micro"
    disk_autoresize = true

    backup_configuration {
      enabled = false
    }

    ip_configuration {
      ipv4_enabled = true

      # Dev/testing only. Restrict in production.
      authorized_networks {
        name  = "all-access"
        value = "0.0.0.0/0"
      }
    }
  }
}

resource "google_sql_database" "db" {
  name     = var.mysql_db
  instance = google_sql_database_instance.mysql.name
}

resource "google_sql_user" "user" {
  name     = var.mysql_user
  instance = google_sql_database_instance.mysql.name
  password = var.mysql_password
}

###########################
# Secret Manager: DB password
###########################
resource "google_secret_manager_secret" "mysql_password" {
  project   = var.project_id
  secret_id = "${var.mysql_user}-password-${var.env}"

  replication {
    auto {}
  }

  depends_on = [
    google_project_service.secretmanager_api
  ]
}

resource "google_secret_manager_secret_version" "mysql_password_v" {
  secret      = google_secret_manager_secret.mysql_password.id
  secret_data = var.mysql_password
}

###########################
# Service Accounts
###########################
resource "google_service_account" "function_sa" {
  account_id   = "etl-fn-sa-${var.env}"
  display_name = "ETL Function SA"
}

resource "google_service_account" "order_function_sa" {
  account_id   = "order-fn-sa-${var.env}"
  display_name = "Order Function SA"
}

###########################
# IAM for Service Accounts
###########################
resource "google_storage_bucket_iam_member" "etl_input_bucket_reader" {
  bucket = google_storage_bucket.input_bucket.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.function_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "mysql_password_access" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.mysql_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.function_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "order_mysql_password_access" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.mysql_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.order_function_sa.email}"
}

###########################
# Pub/Sub
###########################
resource "google_pubsub_topic" "order_events" {
  name       = "${var.topic_name}-${var.env}"
  depends_on = [google_project_service.pubsub_api]
}

resource "google_pubsub_subscription" "order_events_sub" {
  name  = "${var.subscription_name}-${var.env}"
  topic = google_pubsub_topic.order_events.name

  ack_deadline_seconds       = 20
  message_retention_duration = "604800s"

  expiration_policy {
    ttl = ""
  }

  depends_on = [google_pubsub_topic.order_events]
}

###########################
# Archive source: emp-etl
###########################
data "archive_file" "etl_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../emp-etl/src"
  output_path = "${path.module}/etl_function.zip"
}

resource "google_storage_bucket_object" "etl_zip" {
  name       = "etl_function.zip"
  bucket     = google_storage_bucket.code_bucket.name
  source     = data.archive_file.etl_zip.output_path

  depends_on = [google_storage_bucket.code_bucket]
}

###########################
# Archive source: order-service
###########################
data "archive_file" "order_fn_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../order-service-etl/src"
  output_path = "${path.module}/order_function.zip"
}

resource "google_storage_bucket_object" "order_fn_zip" {
  name       = "order_function.zip"
  bucket     = google_storage_bucket.code_bucket.name
  source     = data.archive_file.order_fn_zip.output_path

  depends_on = [google_storage_bucket.code_bucket]
}

###########################
# Cloud Function: emp-etl
###########################
resource "google_cloudfunctions_function" "etl" {
  name        = "etl-function-${var.env}"
  description = "ETL function triggered by GCS file upload"
  runtime     = "python39"
  entry_point = "etl_handler"
  region      = var.region

  service_account_email = google_service_account.function_sa.email

  source_archive_bucket = google_storage_bucket.code_bucket.name
  source_archive_object = google_storage_bucket_object.etl_zip.name

  event_trigger {
    event_type = "google.storage.object.finalize"
    resource   = google_storage_bucket.input_bucket.name
  }

  available_memory_mb = 512
  timeout             = 540

  environment_variables = {
    INPUT_BUCKET = google_storage_bucket.input_bucket.name
    DB_HOST      = google_sql_database_instance.mysql.ip_address[0].ip_address
    DB_NAME      = var.mysql_db
    DB_USER      = var.mysql_user
    DB_PORT      = "3306"
  }

  secret_environment_variables {
    key     = "DB_PASS"
    secret  = google_secret_manager_secret.mysql_password.secret_id
    version = "latest"
  }

  depends_on = [
    google_project_service.cloudfunctions_api,
    google_project_service.cloudbuild_api,
    google_project_service.secretmanager_api,
    google_sql_database_instance.mysql,
    google_sql_database.db,
    google_sql_user.user,
    google_storage_bucket_object.etl_zip,
    google_service_account.function_sa,
    google_storage_bucket_iam_member.etl_input_bucket_reader,
    google_secret_manager_secret.mysql_password,
    google_secret_manager_secret_version.mysql_password_v,
    google_secret_manager_secret_iam_member.mysql_password_access
  ]
}

###########################
# Cloud Function: order-service
###########################
resource "google_cloudfunctions_function" "order_consumer" {
  name        = "order-consumer-${var.env}"
  description = "Consumes order events from Pub/Sub"
  runtime     = "python39"
  entry_point = "process_order_event"
  region      = var.region

  service_account_email = google_service_account.order_function_sa.email

  source_archive_bucket = google_storage_bucket.code_bucket.name
  source_archive_object = google_storage_bucket_object.order_fn_zip.name

  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = google_pubsub_topic.order_events.name
  }

  available_memory_mb = 256
  timeout             = 60

  environment_variables = {
    DB_HOST = google_sql_database_instance.mysql.ip_address[0].ip_address
    DB_NAME = var.mysql_db
    DB_USER = var.mysql_user
    DB_PORT = "3306"
  }

  secret_environment_variables {
    key     = "DB_PASS"
    secret  = google_secret_manager_secret.mysql_password.secret_id
    version = "latest"
  }

  depends_on = [
    google_project_service.cloudfunctions_api,
    google_project_service.cloudbuild_api,
    google_project_service.pubsub_api,
    google_project_service.secretmanager_api,
    google_sql_database_instance.mysql,
    google_sql_database.db,
    google_sql_user.user,
    google_storage_bucket_object.order_fn_zip,
    google_pubsub_topic.order_events,
    google_service_account.order_function_sa,
    google_secret_manager_secret.mysql_password,
    google_secret_manager_secret_version.mysql_password_v,
    google_secret_manager_secret_iam_member.order_mysql_password_access
  ]
}