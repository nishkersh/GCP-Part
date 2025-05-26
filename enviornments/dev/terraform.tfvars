// GCP Project and Region
gcp_project_id      = "your-gcp-project-id"       // <<< REPLACE
gcp_region          = "us-central1"
project_id_prefix   = "acme"                      // <<< REPLACE (e.g., your company/project shortname)

// Common Tags
common_tags = {
  environment      = "dev"
  application-name = "shared-infra-dev"
  owner-contact    = "dev-team@example.com"       // <<< REPLACE
  cost-center      = "development-cc"             // <<< REPLACE
}

// --- VPC Configuration ---
vpc_name                     = "main"
vpc_subnet_bastion_cidr      = "10.100.1.0/24"
vpc_subnet_gke_cidr          = "10.100.2.0/24"
vpc_subnet_gke_pods_cidr     = "10.110.0.0/16"
vpc_subnet_gke_services_cidr = "10.120.0.0/20"
vpc_subnet_db_cidr           = "10.100.3.0/24"
bastion_ssh_source_cidrs     = ["YOUR_HOME_OR_OFFICE_IP/32"] // <<< REPLACE with your actual IP CIDR for SSH access

// --- Bastion Configuration ---
bastion_zone         = "us-central1-a" // Ensure this zone is in gcp_region
bastion_machine_type = "e2-micro"

// --- GKE Configuration ---
gke_cluster_name_suffix    = "primary"
gke_release_channel        = "REGULAR"
gke_kubernetes_version     = null // Use default for REGULAR channel
gke_master_ipv4_cidr_block = "172.16.0.0/28" // Example, ensure it's unique and available
gke_master_authorized_cidrs = {
  "office_network" = "YOUR_OFFICE_IP_RANGE/24" // <<< REPLACE if you need kubectl access from specific IPs
  // Bastion public IP will be added automatically
}
gke_node_pools = {
  default-pool = {
    machine_type    = "e2-medium"
    min_count       = 1
    max_count       = 2
    initial_count   = 1
    disk_size_gb    = 30
    disk_type       = "pd-standard"
    image_type      = "COS_CONTAINERD"
    preemptible     = false
    spot            = false
    # node_locations  = ["us-central1-a", "us-central1-b"] # Optional: specify zones for regional cluster nodes
  }
}
// gke_database_encryption_key = "projects/YOUR_GCP_PROJECT_ID/locations/us-central1/keyRings/my-gke-keyring/cryptoKeys/my-etcd-key" // Optional CMEK

// --- ALB Configuration ---
alb_name_suffix = "app-lb"
alb_domain_name = "dev.your-cool-app.com" // <<< REPLACE with your domain
alb_gke_negs = [
  # Example:
  # {
  #   name = "k8s1-xxxxxxxx-namespace-service-80-yyyyy" // Actual NEG name from GKE service annotation
  #   zone = "us-central1-a" // Zone where the NEG and GKE nodes are
  # }
]
alb_health_check_path = "/healthz"

// --- Database (Cloud SQL PostgreSQL) Configuration ---
db_instance_name_suffix = "main-pg"
db_database_version     = "POSTGRES_15"
db_tier                 = "db-f1-micro" // Smallest instance for dev
db_disk_type            = "PD_SSD"
db_disk_size_gb         = 20
db_name                 = "app_dev_db"
db_user                 = "app_dev_user"
db_user_password_secret_id = "projects/your-gcp-project-id/secrets/dev-db-password/versions/latest" // <<< REPLACE with your Secret Manager path
db_backup_retention_count = 3
db_flags = {
  "log_statement" = "ddl"
}