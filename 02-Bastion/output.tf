output "bastion_instance_name" {
  description = "The name of the bastion host GCE instance."
  value       = google_compute_instance.bastion_host.name
}

output "bastion_instance_self_link" {
  description = "The self-link of the bastion host GCE instance."
  value       = google_compute_instance.bastion_host.self_link
}

output "bastion_public_ip" {
  description = "The public IP address of the bastion host."
  value       = var.create_static_external_ip ? google_compute_address.static_ip[0].address : (length(google_compute_instance.bastion_host.network_interface[0].access_config) > 0 ? google_compute_instance.bastion_host.network_interface[0].access_config[0].nat_ip : null)
}

output "bastion_private_ip" {
  description = "The private IP address of the bastion host."
  value       = google_compute_instance.bastion_host.network_interface[0].network_ip
}

output "bastion_service_account_email" {
  description = "The email of the service account associated with the bastion host."
  value       = local.service_account_email_final
}

output "static_external_ip_address_name" {
  description = "Name of the static external IP address resource, if created."
  value       = var.create_static_external_ip ? google_compute_address.static_ip[0].name : null
}

output "static_external_ip_address" {
  description = "The static external IP address value, if created."
  value       = var.create_static_external_ip ? google_compute_address.static_ip[0].address : null
}