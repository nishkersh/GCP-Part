output "ip_address" {
  description = "The global IP address of the load balancer."
  value       = local.ip_address_value
}

output "static_ip_address_self_link" {
  description = "Self-link of the reserved static IP address, if created."
  value       = var.create_static_ip && var.existing_static_ip_address_self_link == null ? google_compute_global_address.default[0].self_link : var.existing_static_ip_address_self_link
}

output "managed_ssl_certificate_name" {
  description = "Name of the Google-managed SSL certificate."
  value       = google_compute_managed_ssl_certificate.default.name
}

output "managed_ssl_certificate_names" {
  description = "Names of the Google-managed SSL certificates (compatibility, use singular)."
  value       = [google_compute_managed_ssl_certificate.default.name]
}


output "backend_service_name" {
  description = "Name of the default backend service."
  value       = google_compute_backend_service.default.name
}

output "backend_service_self_link" {
  description = "Self-link of the default backend service."
  value       = google_compute_backend_service.default.self_link
}

output "url_map_name" {
  description = "Name of the URL map."
  value       = google_compute_url_map.default.name
}

output "target_https_proxy_name" {
  description = "Name of the Target HTTPS Proxy."
  value       = google_compute_target_https_proxy.default.name
}

output "https_forwarding_rule_name" {
  description = "Name of the HTTPS Global Forwarding Rule."
  value       = google_compute_global_forwarding_rule.https.name
}

output "http_forwarding_rule_name" {
  description = "Name of the HTTP Global Forwarding Rule (for redirect), if created."
  value       = var.http_to_https_redirect ? google_compute_global_forwarding_rule.http[0].name : null
}