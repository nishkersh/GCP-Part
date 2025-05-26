output "vpc_network_name" {
  description = "Name of the VPC network."
  value       = module.vpc.network_name
}

output "vpc_network_self_link" {
  description = "Self-link of the VPC network."
  value       = module.vpc.network_self_link
}

output "vpc_subnets" {
  description = "Details of the created subnets."
  value       = module.vpc.subnets_details
}

output "bastion_public_ip" {
  description = "Public IP address of the bastion host."
  value       = module.bastion.bastion_public_ip
}

output "bastion_instance_name" {
  description = "Name of the bastion host instance."
  value       = module.bastion.bastion_instance_name
}

output "gke_cluster_name" {
  description = "Name of the GKE cluster."
  value       = module.gke.cluster_name
}

output "gke_cluster_endpoint" {
  description = "Endpoint of the GKE cluster (private if configured)."
  value       = module.gke.cluster_endpoint
}

output "gke_cluster_ca_certificate" {
  description = "CA certificate for the GKE cluster."
  value       = module.gke.cluster_ca_certificate
  sensitive   = true
}

output "gke_node_pool_service_accounts" {
  description = "Service accounts used by GKE node pools."
  value       = module.gke.node_pools_service_accounts
}

output "database_instance_name" {
  description = "Name of the Cloud SQL instance."
  value       = module.database.instance_name
}

output "database_instance_connection_name" {
  description = "Connection name of the Cloud SQL instance (for Cloud SQL Proxy)."
  value       = module.database.instance_connection_name
}

output "database_instance_private_ip" {
  description = "Private IP address of the Cloud SQL instance."
  value       = module.database.instance_private_ip
}

output "alb_ip_address" {
  description = "Global IP address of the HTTP(S) Load Balancer."
  value       = module.alb.ip_address
}

output "alb_managed_ssl_certificate_names" {
  description = "Names of the Google-managed SSL certificates."
  value       = module.alb.managed_ssl_certificate_names
}