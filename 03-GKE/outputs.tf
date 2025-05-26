output "cluster_name" {
  description = "The name of the GKE cluster."
  value       = google_container_cluster.primary.name
}

output "cluster_id" {
  description = "The ID of the GKE cluster."
  value       = google_container_cluster.primary.id
}

output "cluster_endpoint" {
  description = "The IP address of this cluster's master endpoint."
  value       = google_container_cluster.primary.endpoint
  sensitive   = true # Endpoint might be private
}

output "cluster_private_endpoint" {
  description = "The private IP address of this cluster's master endpoint (if private cluster is enabled)."
  value       = google_container_cluster.primary.private_cluster_config[0].private_endpoint
  sensitive   = true
}

output "cluster_public_endpoint" {
  description = "The public IP address of this cluster's master endpoint (if public endpoint is enabled)."
  value       = google_container_cluster.primary.private_cluster_config[0].public_endpoint # This is actually the public endpoint if enabled
  sensitive   = true
}

output "cluster_master_version" {
  description = "The current master Kubernetes version."
  value       = google_container_cluster.primary.master_version
}

output "cluster_ca_certificate" {
  description = "The public certificate that is the root of trust for the cluster."
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "location" {
  description = "The location (region or zone) of the GKE cluster."
  value       = google_container_cluster.primary.location
}

output "node_pools_names" {
  description = "A list of GKE node pool names."
  value       = [for np in google_container_node_pool.pools : np.name]
}

output "node_pools_versions" {
  description = "A map of GKE node pool names to their current node versions."
  value       = { for k, v in google_container_node_pool.pools : k => v.version }
}

output "node_pools_service_accounts" {
  description = "A map of GKE node pool names to their service account emails."
  value = {
    for k, v in google_container_node_pool.pools :
    k => v.node_config[0].service_account
  }
}

output "workload_identity_pool" {
  description = "The workload identity pool associated with the cluster."
  value       = local.effective_workload_identity_pool
}

output "gke_service_account_email" {
  description = "The email of the Google-managed GKE service account (service-<PROJECT_NUMBER>@container-engine-robot.iam.gserviceaccount.com). This SA needs permissions for CMEK if used."
  value       = "service-${data.google_project.current.number}@container-engine-robot.iam.gserviceaccount.com"
}

data "google_project" "current" {
  project_id = var.project_id
}