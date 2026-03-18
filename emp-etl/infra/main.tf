# ========================
# Buckets
# ========================
resource "google_storage_bucket" "etl_code_bucket" {
  name          = var.code_bucket_name
  location      = var.region
  force_destroy = true
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "etl_input_bucket" {
  name          = var.input_bucket_name
  location      = var.region
  force_destroy = true
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "etl_output_bucket" {
  name          = var.output_bucket_name
  location      = var.region
  force_destroy = true
  uniform_bucket_level_access = true
}

# ========================
# Cloud SQL MySQL Instance (Public)
# ========================
resource "google_sql_database_instance" "mysql_instance" {
  name             = "etl-mysql-instance"
  database_version = "MYSQL_8_0"
  region           = var.region
  deletion_protection = false 
  settings {
    tier = "db-f1-micro"

    ip_configuration {
      ipv4_enabled = true

      authorized_networks {
        name  = "all"
        value = "0.0.0.0/0"  # WARNING: public access
      }
    }
  }
}

resource "google_sql_database" "etl_db" {
  name     = var.mysql_db
  instance = google_sql_database_instance.mysql_instance.name
}

resource "google_sql_user" "etl_user" {
  name     = var.mysql_user
  instance = google_sql_database_instance.mysql_instance.name
  password = var.mysql_password
}

# ========================
# Secret Manager for MySQL
# ========================

# MySQL Username
resource "google_secret_manager_secret" "mysql_user" {
  secret_id = "MYSQL_USER"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "mysql_user_version" {
  secret      = google_secret_manager_secret.mysql_user.id
  secret_data = var.mysql_user
}

# MySQL Password
resource "google_secret_manager_secret" "mysql_password" {
  secret_id = "MYSQL_PASSWORD"
  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "mysql_password_version" {
  secret      = google_secret_manager_secret.mysql_password.id
  secret_data = var.mysql_password
}

# Zip the function automatically
data "archive_file" "etl_function_zip" {
  type        = "zip"
  source_dir  = "../src/"
  output_path = "${path.module}/etl_function.zip"
}

# Upload ZIP to Google Cloud Storage
resource "google_storage_bucket_object" "etl_function_zip" {
  name   = "etl_function.zip"
  bucket = google_storage_bucket.etl_code_bucket.name
  source = data.archive_file.etl_function_zip.output_path
}
# ========================
# Cloud Function for ETL (Event-triggered)
# ========================
resource "google_cloudfunctions_function" "etl_function" {
  name        = var.function_name
  runtime     = var.function_runtime
  entry_point = "etl_handler"

  source_archive_bucket = google_storage_bucket.etl_code_bucket.name
  source_archive_object = google_storage_bucket_object.etl_function_zip.name

  event_trigger {
    event_type = "google.storage.object.finalize"
    resource   = google_storage_bucket.etl_input_bucket.name
  }

  environment_variables = {
    MYSQL_HOST     = google_sql_database_instance.mysql_instance.public_ip_address
    MYSQL_USER     = var.mysql_user
    MYSQL_PASSWORD = var.mysql_password
    MYSQL_DB       = var.mysql_db
    BUCKET_NAME    = google_storage_bucket.etl_input_bucket.name
  }
}

resource "google_storage_bucket_iam_member" "function_bucket_reader" {
  bucket = google_storage_bucket.etl_input_bucket.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:project-d25d1c66-5ac7-43e4-974@appspot.gserviceaccount.com"
}

# IAM: Give Cloud Function access to read secrets
# resource "google_project_iam_member" "cloud_function_secret_access_user" {
#   project = var.project_id
#   role    = "roles/secretmanager.secretAccessor"
#   member  = "serviceAccount:${google_cloudfunctions_function.etl_function.service_account_email}"
# }

# resource "google_project_iam_member" "cloud_function_secret_access_password" {
#   project = var.project_id
#   role    = "roles/secretmanager.secretAccessor"
#   member  = "serviceAccount:${google_cloudfunctions_function.etl_function.service_account_email}"
# }