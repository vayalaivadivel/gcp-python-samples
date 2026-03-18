# ========================
# Outputs
# ========================
output "mysql_public_ip" {
  description = "Public IP of MySQL instance"
  value       = google_sql_database_instance.mysql_instance.public_ip_address
}

output "mysql_username" {
  value = google_sql_user.etl_user.name
}

output "mysql_password" {
  value     = google_sql_user.etl_user.password
  sensitive = true
}

output "mysql_connection_url" {
  value     = "mysql://${google_sql_user.etl_user.name}:${google_sql_user.etl_user.password}@${google_sql_database_instance.mysql_instance.public_ip_address}:3306/${google_sql_database.etl_db.name}"
  sensitive = true
}

output "input_bucket_name" {
  value = google_storage_bucket.etl_input_bucket.name
}

output "output_bucket_name" {
  value = google_storage_bucket.etl_output_bucket.name
}

output "code_bucket_name" {
  value = google_storage_bucket.etl_code_bucket.name
}