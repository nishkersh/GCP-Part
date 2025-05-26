variable "gcp_project_id" {
  description = "The GCP project ID to deploy resources into."
  type        = string
}

variable "gcp_region" {
  description = "The GCP region for regional resources."
  type        = string
}

variable "project_id_prefix" {
  description = "A prefix used for naming resources, e.g., 'acme'."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_id_prefix)) && length(var.project_id_prefix) <= 15
    error_message = "Project ID prefix must be lowercase alphanumeric, hyphens allowed, and max 15 chars."
  }
}

variable "common_tags" {
  description = "Common tags to apply to all resources."
  type        = map(string)
  default = {
    managed-by = "terraform"
  }
}

// --- VPC Variables ---
variable "vpc_name" {
  description = "Name suffix for the VPC network (e.g., 'main')."
  type        = string
  default     = "main"
}

variable "vpc_subnet_bastion_cidr" {
  description = "CIDR block for the bastion public subnet."
  type        = string
}

variable "vpc_subnet_gke_cidr" {
  description = "Primary CIDR block for the GKE private subnet."
  type        = string
}

variable "vpc_subnet_gke_pods_cidr" {
  description = "Secondary CIDR block for GKE Pods in the GKE subnet."
  type        = string
}

variable "vpc_subnet_gke_services_cidr" {
  description = "Secondary CIDR block for GKE Services in the GKE subnet."
  type        = string
}

variable "vpc_subnet_db_cidr" {
  description = "CIDR block for the database private subnet."
  type        = string
}

variable "bastion_ssh_source_cidrs" {
  description = "List of source IP CIDR blocks allowed for SSH access to the bastion host."
  type        = list(string)
  default     = ["0.0.0.0/0"] # WARNING: Open to the world. Restrict this in production.
}

variable "enable_vpc_flow_logs" {
  description = "Flag to enable VPC flow logs."
  type        = bool
  default     = true
}

// --- Bastion Variables ---
variable "bastion_zone" {
  description = "GCP zone for the bastion host. Should be in var.gcp_region."
  type        = string
  default     = null # If null, module will pick first zone in region
}

variable "bastion_machine_type" {
  description = "Machine type for the bastion host."
  type        = string
  default     = "e2-micro"
}

variable "bastion_boot_disk_image" {
  description = "Boot disk image for the bastion host."
  type        = string
  default     = "debian-cloud/debian-11"
}

// --- GKE Variables ---
variable "gke_cluster_name_suffix" {
  description = "Suffix for the GKE cluster name."
  type        = string
  default     = "primary"
}

variable "gke_release_channel" {
  description = "The release channel of the GKE cluster."
  type        = string
  default     = "REGULAR" # Options: RAPID, REGULAR, STABLE
  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE", "UNSPECIFIED"], var.gke_release_channel)
    error_message = "Invalid GKE release channel. Must be one of: RAPID, REGULAR, STABLE, UNSPECIFIED."
  }
}

variable "gke_kubernetes_version" {
  description = "The Kubernetes version for the GKE cluster. If null, uses the default for the selected release channel."
  type        = string
  default     = null
}

variable "gke_master_ipv4_cidr_block" {
  description = "The /28 CIDR block for the GKE master's internal IP range. Must be unique and not overlap with other networks."
  type        = string
  default     = null # If null, GKE will auto-assign. Recommended to set for predictability.
}

variable "gke_master_authorized_cidrs" {
  description = "Map of display names to CIDR blocks for GKE master authorized networks."
  type        = map(string)
  default     = {}
}

variable "gke_node_pools" {
  description = "A map of GKE node pool configurations."
  type = map(object({
    machine_type    = string
    disk_size_gb    = number
    disk_type       = string
    image_type      = string
    min_count       = number
    max_count       = number
    initial_count   = number
    preemptible     = bool
    spot            = bool
    node_locations  = optional(list(string)) # For zonal node pools in a regional cluster
    service_account = optional(string)       # Optional: existing SA email. If null, module creates one.
    oauth_scopes    = optional(list(string))
    tags            = optional(list(string))
    labels          = optional(map(string))
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })))
  }))
}

variable "gke_enable_network_policy" {
  description = "Enable network policy (e.g., Calico) on the GKE cluster."
  type        = bool
  default     = true
}

variable "gke_enable_workload_identity" {
  description = "Enable Workload Identity on the GKE cluster."
  type        = bool
  default     = true
}

variable "gke_database_encryption_key" {
  description = "Optional: The self-link of the KMS key to be used for GKE database encryption (etcd encryption). e.g., projects/PROJECT_ID/locations/REGION/keyRings/KEYRING_NAME/cryptoKeys/KEY_NAME"
  type        = string
  default     = null
}

// --- ALB Variables ---
variable "alb_name_suffix" {
  description = "Suffix for the ALB resources."
  type        = string
  default     = "main-https"
}

variable "alb_domain_name" {
  description = "The domain name for which the Google-managed SSL certificate will be created."
  type        = string
}

variable "alb_gke_negs" {
  description = "A list of objects describing GKE Network Endpoint Groups (NEGs) to be used as backends. Ensure these NEGs are created by GKE service annotations."
  type = list(object({
    name = string # Name of the NEG (e.g., k8s1-e41fac14-default-my-service-80-NEG_NAME_SUFFIX)
    zone = string # Zone of the NEG (for zonal NEGs)
    # For regional NEGs, you might need 'region' instead of 'zone' depending on NEG type. GKE service NEGs are zonal.
  }))
  default = []
}

variable "alb_health_check_path" {
  description = "Path for the ALB health check."
  type        = string
  default     = "/"
}

variable "alb_cloud_armor_policy_name" {
  description = "Optional: Name of the Cloud Armor security policy to attach to the backend service. The policy must exist in the same project."
  type        = string
  default     = null
}

// --- Database (Cloud SQL PostgreSQL) Variables ---
variable "db_instance_name_suffix" {
  description = "Suffix for the Cloud SQL instance name."
  type        = string
  default     = "main-pg"
}

variable "db_database_version" {
  description = "PostgreSQL version for the Cloud SQL instance."
  type        = string
  default     = "POSTGRES_15"
}

variable "db_tier" {
  description = "Machine type for the Cloud SQL instance."
  type        = string
}

variable "db_availability_type" {
  description = "Availability type for the Cloud SQL instance (e.g., REGIONAL for HA)."
  type        = string
  default     = "REGIONAL"
}

variable "db_disk_type" {
  description = "Disk type for Cloud SQL (PD_SSD or PD_HDD)."
  type        = string
  default     = "PD_SSD"
}

variable "db_disk_size_gb" {
  description = "Disk size in GB for the Cloud SQL instance."
  type        = number
}

variable "db_name" {
  description = "Name of the initial database to create."
  type        = string
}

variable "db_user" {
  description = "Name of the initial database user."
  type        = string
}

variable "db_user_password_secret_id" {
  description = "The Secret Manager secret ID (format: projects/{project}/secrets/{secret}/versions/{version|latest}) for the database user's password."
  type        = string
  validation {
    condition     = can(regex("^projects/[^/]+/secrets/[^/]+/versions/[^/]+$", var.db_user_password_secret_id))
    error_message = "Invalid Secret Manager secret ID format."
  }
}

variable "db_backup_retention_count" {
  description = "Number of automated backups to retain."
  type        = number
  default     = 7
}

variable "db_point_in_time_recovery_enabled" {
  description = "Enable point-in-time recovery for the database."
  type        = bool
  default     = true
}

variable "db_flags" {
  description = "Map of database flags to set on the Cloud SQL instance."
  type        = map(string)
  default     = {} # Example: { "log_min_duration_statement" = "250" }
}