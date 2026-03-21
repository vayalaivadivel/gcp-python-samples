# ========================
# Outputs
# ========================
output "mysql_public_ip" {
  description = "Public IP of MySQL instance"
   value = google_sql_database_instance.mysql.public_ip_address
}

output "source_code_bucket" {
  value     = google_storage_bucket.code_bucket
}

output "input_bucket" {
  value = google_storage_bucket.input_bucket.name
}