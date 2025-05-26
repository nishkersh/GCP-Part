output "instance_name" {
  description = "The name of the Cloud SQL instance."
  value       = google_sql_database_instance.instance.name
}

output "instance_connection_name" {
  description = "The connection name of the Cloud SQL instance (project:region:instance)."
  value       = google_sql_database_instance.instance.connection_name
}

output "instance_self_link" {
  description = "The self-link of the Cloud SQL instance."
  value       = google_sql_database_instance.instance.self_link
}

output "instance_service_account_email_address" {
  description = "The service account email address assigned to the Cloud SQL instance."
  value       = google_sql_database_instance.instance.service_account_email_address
}

output "instance_public_ip_address" {
  description = "The public IPv4 address of the Cloud SQL instance (if enabled)."
  value       = length(google_sql_database_instance.instance.ip_address) > 0 && google_sql_database_instance.instance.settings[0].ip_configuration[0].ipv4_enabled ? google_sql_database_instance.instance.ip_address[0].ip_address : null
}

output "instance_private_ip_address" {
  description = "The private IPv4 address of the Cloud SQL instance (if enabled)."
  value       = length(google_sql_database_instance.instance.ip_address) > 0 && local.enable_private_ip && length(google_sql_database_instance.instance.private_ip_address) > 0 ? google_sql_database_instance.instance.private_ip_address : (length(google_sql_database_instance.instance.ip_address) > 1 && local.enable_private_ip ? google_sql_database_instance.instance.ip_address[1].ip_address : null)
  # Note: The 'private_ip_address' attribute on the instance is sometimes not populated immediately or reliably.
  # Checking the ip_address block for an entry with type "PRIVATE" is more robust.
  # For simplicity, this output might need adjustment based on observed behavior or by iterating ip_address list.
}

output "instance_first_ip_address" {
  description = "The first IP address of the Cloud SQL instance (could be public or private)."
  value       = google_sql_database_instance.instance.first_ip_address # This is often the public IP if enabled, or private if only private.
}

output "db_name_created" {
  description = "The name of the initial database created."
  value       = google_sql_database.initial_db.name
}

output "db_user_name_created" {
  description = "The name of the initial user created."
  value       = google_sql_user.initial_user.name
}

output "db_user_password_secret_id_used" {
  description = "The Secret Manager Secret ID used for the database user's password."
  value       = var.db_user_password_secret_id
}