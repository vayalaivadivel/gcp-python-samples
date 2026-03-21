# ========================
# Input Cloud Storage Bucket
# ========================
resource "google_storage_bucket" "input_bucket" {
  name     = "${var.project_id}-input-${var.env}"
  location = var.region

  force_destroy               = var.env == "dev" ? true : false
  uniform_bucket_level_access = true

  labels = {
    env  = var.env
    type = "input"
  }
}

# ========================
# Cloud SQL MySQL
# ========================
resource "google_sql_database_instance" "mysql" {
  name             = "etl-emp-${var.env}"
  database_version = "MYSQL_8_0"
  region           = var.region

  deletion_protection = var.env == "prod" ? true : false

  settings {
    tier = "db-f1-micro"

    ip_configuration {
      ipv4_enabled = true

      # 🔹 Only allow your laptop/public IP to connect
      authorized_networks {
        name  = "laptop"
        value = var.my_ip  # e.g., "1.2.3.4/32"
      }
    }

    backup_configuration {
      enabled = var.env == "prod" ? true : false
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

# ========================
# Secret Manager
# ========================
resource "google_secret_manager_secret" "mysql_password" {
  secret_id = "mysql-password-${var.env}"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "mysql_password_v" {
  secret      = google_secret_manager_secret.mysql_password.id
  secret_data = var.mysql_password
}

# ========================
# Service Account for Cloud Function
# ========================
resource "google_service_account" "function_sa" {
  account_id   = "etl-fn-sa-${var.env}"
  display_name = "ETL Function SA"
}

resource "google_project_iam_member" "secret_access" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.function_sa.email}"
}

resource "google_project_iam_member" "storage_access" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.function_sa.email}"
}

# ========================
# Cloud Function (event-driven on input bucket)
# ========================
resource "google_storage_bucket" "code_bucket" {
  name     = "${var.project_id}-function-code-${var.env}"
  location = var.region
  force_destroy = true
}

resource "google_storage_bucket_object" "etl_zip" {
  name   = "empty.zip"
  bucket = google_storage_bucket.code_bucket.name
  source = "${path.module}/empty.zip" # minimal stub
}

resource "google_cloudfunctions_function" "etl" {
  name        = "${var.function_name}-${var.env}"
  runtime     = var.function_runtime
  entry_point = "etl_handler"
  region      = var.region

  service_account_email = google_service_account.function_sa.email

  source_archive_bucket = google_storage_bucket.code_bucket.name
  source_archive_object = google_storage_bucket_object.etl_zip.name

  # 🔹 Event-based trigger
  event_trigger {
    event_type = "google.storage.object.finalize"
    resource   = google_storage_bucket.input_bucket.name
  }

  available_memory_mb = 512
  timeout             = 540

  environment_variables = {
    INPUT_BUCKET = google_storage_bucket.input_bucket.name

    DB_HOST = google_sql_database_instance.mysql.public_ip_address
    DB_NAME = var.mysql_db
    DB_USER = var.mysql_user
  }

  secret_environment_variables {
    key     = "DB_PASS"
    secret  = google_secret_manager_secret.mysql_password.secret_id
    version = "latest"
  }
}