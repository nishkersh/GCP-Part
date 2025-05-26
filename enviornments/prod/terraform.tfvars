// GCP Project and Region
gcp_project_id      = "your-gcp-project-id"       // <<< REPLACE
gcp_region          = "us-west1"                  // Different region for prod HA example
project_id_prefix   = "acme"                      // <<< REPLACE

// Common Tags
common_tags = {
  environment      = "production"
  application-name = "shared-infra-prod"
  owner-contact    = "prod-ops-team@example.com"  // <<< REPLACE
  cost-center      = "production-cc"              // <<< REPLACE
}

// --- VPC Configuration ---
vpc_name                     = "main"
vpc_subnet_bastion_cidr      = "10.200.1.0/24"
vpc_subnet_gke_cidr          = "10.200.2.0/24"
vpc_subnet_gke_pods_cidr     = "10.210.0.0/16"
vpc_subnet_gke_services_cidr = "10.220.0.0/20"
vpc_subnet_db_cidr           = "10.200.3.0/24"
bastion_ssh_source_cidrs     = ["YOUR_SECURE_VPN_EXIT_IP/32", "ANOTHER_ADMIN_IP/32"] // <<< REPLACE: Highly restricted for prod

// --- Bastion Configuration ---
bastion_zone         = "us-west1-a"
bastion_machine_type = "e2-small" // Slightly larger for prod if needed, or keep micro

// --- GKE Configuration ---
gke_cluster_name_suffix    = "primary"
gke_release_channel        = "STABLE" // More conservative for production
gke_kubernetes_version     = null     // Use default for STABLE channel
gke_master_ipv4_cidr_block = "172.16.1.0/28" // Ensure unique
gke_master_authorized_cidrs = {
  "prod_vpn_access" = "YOUR_PROD_VPN_CIDR/24" // <<< REPLACE
}
gke_node_pools = {
  general-purpose = {
    machine_type    = "n2-standard-2" // More robust machine type for prod
    min_count       = 2               // Minimum 2 for HA per zone
    max_count       = 10
    initial_count   = 2
    disk_size_gb    = 100
    disk_type       = "pd-ssd"        // Faster disk for prod
    image_type      = "COS_CONTAINERD"
    preemptible     = false
    spot            = false
    node_locations  = ["us-west1-a", "us-west1-b", "us-west1-c"] // Spread across zones in regional cluster
  },
  // Example of a high-memory node pool
  // high-memory-pool = {
  //   machine_type    = "n2-highmem-4"
  //   min_count       = 1
  //   max_count       = 5
  //   initial_count   = 1
  //   disk_size_gb    = 100
  //   disk_type       = "pd-ssd"
  //   image_type      = "COS_CONTAINERD"
  //   preemptible     = false
  //   spot            = false
  // }
}
gke_database_encryption_key = "projects/your-gcp-project-id/locations/us-west1/keyRings/prod-gke-keyring/cryptoKeys/prod-etcd-key" // Strongly recommend CMEK for prod

// --- ALB Configuration ---
alb_name_suffix = "app-lb"
alb_domain_name = "app.your-cool-app.com" // <<< REPLACE with your production domain
alb_gke_negs = [
  // Example:
  // {
  //   name = "k8s1-zzzzzzzz-prodspace-prodsvc-80-wwww" // Actual NEG name from GKE service annotation
  //   zone = "us-west1-a" // Zone where the NEG and GKE nodes are
  // }
]
alb_health_check_path = "/healthz"
// alb_cloud_armor_policy_name = "prod-armor-policy" // Recommended for production

// --- Database (Cloud SQL PostgreSQL) Configuration ---
db_instance_name_suffix = "main-pg"
db_database_version     = "POSTGRES_15"
db_tier                 = "db-custom-2-7680" // Custom, e.g., 2 vCPU, 7.5GB RAM for prod
db_availability_type    = "REGIONAL"         // HA is critical for prod
db_disk_type            = "PD_SSD"
db_disk_size_gb         = 100                // Larger disk for prod
db_name                 = "app_prod_db"
db_user                 = "app_prod_user"
db_user_password_secret_id = "projects/your-gcp-project-id/secrets/prod-db-password/versions/latest" // <<< REPLACE: Separate secret for prod
db_backup_retention_count = 30 // Longer retention for prod
db_point_in_time_recovery_enabled = true
db_flags = {
  "log_min_duration_statement" = "1000", // Log statements longer than 1s
  "log_lock_waits" = "on",
  "shared_buffers" = "1920MB" // Example: 25% of 7.5GB RAM
}