# ========================
# Outputs
# ========================
output "mysql_public_ip" {
  description = "Public IP of MySQL instance"
   value = google_sql_database_instance.mysql.public_ip_address
}

output "mysql_username" {
  value     = google_sql_user.user
}

output "input_bucket" {
  value = google_storage_bucket.input_bucket.name
}