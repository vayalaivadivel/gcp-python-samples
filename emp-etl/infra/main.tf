###########################
# Buckets
###########################
resource "google_storage_bucket" "code_bucket" {
  name          = "${var.project_id}-function-code-${var.env}"
  location      = var.region
  force_destroy = true

  uniform_bucket_level_access = true

  labels = {
    "goog-terraform-provisioned" = "true"
  }
}

resource "google_storage_bucket" "input_bucket" {
  name          = "${var.project_id}-input-${var.env}"
  location      = var.region
  force_destroy = true

  uniform_bucket_level_access = true

  labels = {
    "env"  = var.env
    "type" = "input"
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
  secret_id = "${var.mysql_user}-password-${var.env}"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "mysql_password_v" {
  secret      = google_secret_manager_secret.mysql_password.id
  secret_data = var.mysql_password
}

###########################
# Service Account for Cloud Function
###########################
resource "google_service_account" "function_sa" {
  account_id   = "etl-fn-sa-${var.env}"
  display_name = "ETL Function SA"
}

###########################
# IAM for Service Account
###########################
resource "google_project_iam_member" "storage_access" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.function_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "mysql_password_access" {
  secret_id = google_secret_manager_secret.mysql_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.function_sa.email}"
}

###########################
# Create Zip from src
###########################
data "archive_file" "etl_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../src"
  output_path = "${path.module}/etl_function.zip"
}

resource "google_storage_bucket_object" "etl_zip" {
  name       = "etl_function.zip"
  bucket     = google_storage_bucket.code_bucket.name
  source     = data.archive_file.etl_zip.output_path
  depends_on = [google_storage_bucket.code_bucket]
}

###########################
# Cloud Function (event-based)
###########################
resource "google_cloudfunctions_function" "etl" {
  name        = "etl-function-${var.env}"
  runtime     = "python311"
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
  }

  secret_environment_variables {
    key     = "DB_PASS"
    secret  = google_secret_manager_secret.mysql_password.secret_id
    version = "latest"
  }

  depends_on = [
    google_sql_database_instance.mysql,
    google_sql_database.db,
    google_sql_user.user,
    google_storage_bucket_object.etl_zip,
    google_service_account.function_sa,
    google_project_iam_member.storage_access,
    google_secret_manager_secret_iam_member.mysql_password_access,
    google_secret_manager_secret_version.mysql_password_v
  ]
}