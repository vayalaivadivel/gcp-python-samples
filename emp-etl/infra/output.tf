# ========================
# Outputs
# ========================
output "mysql_public_ip" {
  description = "Public IP of MySQL instance"
   value = google_sql_database_instance.mysql.public_ip_address
}

output "source_code_bucket" {
  value     = google_storage_bucket.code_bucket.name
}

output "input_bucket" {
  value = google_storage_bucket.input_bucket.name
}

output "debug_function_env" {
  value = {
    DB_HOST = try(google_sql_database_instance.mysql.ip_address[0].ip_address, "")
    DB_NAME = var.mysql_db
    DB_USER = var.mysql_user
  }
}