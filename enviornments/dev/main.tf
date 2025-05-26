locals {
  project_id = var.gcp_project_id
  region     = var.gcp_region
  env_prefix = "${var.project_id_prefix}-${var.common_tags.environment}"

  # Merge common_tags with module-specific or resource-specific tags if needed
  global_labels = merge(var.common_tags, {
    "managed-by" = "terraform"
  })

  # GKE master authorized networks: combine user-defined CIDRs with bastion public IP
  gke_master_auth_networks_combined = merge(var.gke_master_authorized_cidrs,
    module.bastion.bastion_public_ip != null ? { "bastion_host" = "${module.bastion.bastion_public_ip}/32" } : {}
  )

  # Construct GKE node pool service account names if not provided
  gke_node_pools_processed = {
    for k, v in var.gke_node_pools : k => merge(v, {
      service_account = coalesce(v.service_account, null) # Let GKE module create SA if not specified
      tags            = distinct(concat(coalesce(v.tags, []), ["${local.env_prefix}-gke-node"]))
      labels          = merge(local.global_labels, coalesce(v.labels, {}))
    })
  }
}

// --- Provider Configuration ---
provider "google" {
  project = local.project_id
  region  = local.region
}

provider "google-beta" {
  project = local.project_id
  region  = local.region
}

// --- VPC Module ---
module "vpc" {
  source = "../../modules/vpc"

  project_id   = local.project_id
  network_name = "${local.env_prefix}-vpc-${var.vpc_name}"
  region       = local.region
  labels       = local.global_labels

  subnets = [
    {
      name                     = "${local.env_prefix}-snet-bastion"
      ip_cidr_range            = var.vpc_subnet_bastion_cidr
      region                   = local.region
      private_ip_google_access = false # Bastion subnet might not need this
      purpose                  = "PRIVATE" # Still a private subnet, NAT provides egress
      role                     = null      # Not a GKE subnet
    },
    {
      name                     = "${local.env_prefix}-snet-gke"
      ip_cidr_range            = var.vpc_subnet_gke_cidr
      region                   = local.region
      private_ip_google_access = true
      purpose                  = "PRIVATE_GKE_CONTAINER_SUBNET" # Explicitly for GKE
      role                     = "PRIMARY"                      # For GKE
      secondary_ip_ranges = {
        "${local.env_prefix}-gke-pods" : var.vpc_subnet_gke_pods_cidr,
        "${local.env_prefix}-gke-services" : var.vpc_subnet_gke_services_cidr
      }
    },
    {
      name                     = "${local.env_prefix}-snet-db"
      ip_cidr_range            = var.vpc_subnet_db_cidr
      region                   = local.region
      private_ip_google_access = true # For Private Service Access & direct connections
      purpose                  = "PRIVATE"
      role                     = null
    }
  ]

  enable_cloud_nat = true
  nat_subnetworks = [
    {
      name = "${local.env_prefix}-snet-bastion" # Name of the subnet to NAT
      source_ip_ranges_to_nat = ["PRIMARY_IP_RANGE"] # Can be ALL_IP_RANGES_IN_SUBNET
    },
    {
      name = "${local.env_prefix}-snet-gke"
      source_ip_ranges_to_nat = ["ALL_IP_RANGES"] # Includes primary and secondary
    },
    {
      name = "${local.env_prefix}-snet-db"
      source_ip_ranges_to_nat = ["PRIMARY_IP_RANGE"]
    }
  ]

  firewall_rules = [
    // Allow SSH to bastion hosts from specified CIDRs
    {
      name        = "${local.env_prefix}-fw-allow-ssh-to-bastion"
      description = "Allow SSH to bastion hosts"
      direction   = "INGRESS"
      priority    = 1000
      ranges      = var.bastion_ssh_source_cidrs
      allow = [{
        protocol = "tcp"
        ports    = ["22"]
      }]
      target_tags = ["${local.env_prefix}-bastion-host"] # Tag applied to bastion instance
    },
    // Allow Cloud SQL access from GKE nodes and Bastion
    {
      name        = "${local.env_prefix}-fw-allow-sql-from-gke-bastion"
      description = "Allow PostgreSQL access from GKE nodes and Bastion to Cloud SQL"
      direction   = "INGRESS"
      priority    = 1000
      source_tags = ["${local.env_prefix}-gke-node", "${local.env_prefix}-bastion-host"] # Tags on GKE nodes and Bastion
      destination_ranges = module.database.instance_private_ip != null ? ["${module.database.instance_private_ip}/32"] : [] # Target Cloud SQL private IP
      allow = [{
        protocol = "tcp"
        ports    = ["5432"]
      }]
      disabled = module.database.instance_private_ip == null # Disable rule if DB IP not yet known
    },
    // Allow GKE control plane to nodes (if using public endpoint with authorized networks)
    // The GKE module itself handles the necessary firewall rules for private clusters.
    // This is an example if you had specific needs for public endpoints.
    // {
    //   name        = "${local.env_prefix}-fw-allow-gke-cp-to-nodes"
    //   description = "Allow GKE control plane to nodes for health checks and control"
    //   direction   = "INGRESS"
    //   priority    = 1000
    //   ranges      = [module.gke.master_ipv4_cidr_block] # This is for private endpoint, for public it's Google managed IPs
    //   allow = [{
    //     protocol = "tcp"
    //     ports    = ["10250", "443"] # Kubelet API, etc.
    //   }]
    //   target_tags = ["${local.env_prefix}-gke-node"]
    //   disabled    = module.gke.master_ipv4_cidr_block == null
    // }
  ]

  enable_flow_logs = var.enable_vpc_flow_logs
  flow_logs_config = var.enable_vpc_flow_logs ? {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  } : null
}

// --- Bastion Module ---
module "bastion" {
  source = "../../modules/bastion"

  project_id   = local.project_id
  zone         = var.bastion_zone != null ? var.bastion_zone : "${local.region}-a" # Default to zone 'a' if not specified
  name_prefix  = "${local.env_prefix}-bastion"
  machine_type = var.bastion_machine_type
  network_name = module.vpc.network_name
  subnet_name  = module.vpc.subnets["${local.env_prefix}-snet-bastion"].name // Referencing by constructed name
  // subnet_name  = element([for snet in module.vpc.subnets_details : snet.name if contains(snet.name, "bastion")], 0) // Alternative way to find subnet
  source_image = var.bastion_boot_disk_image
  labels       = local.global_labels
  tags         = ["${local.env_prefix}-bastion-host"] // Used by firewall rule
}

// --- GKE Module ---
module "gke" {
  source = "../../modules/gke"

  project_id                   = local.project_id
  name                         = "${local.env_prefix}-gke-${var.gke_cluster_name_suffix}"
  region                       = local.region
  network_name                 = module.vpc.network_name
  subnetwork_name              = module.vpc.subnets["${local.env_prefix}-snet-gke"].name
  ip_range_pods_name           = "${local.env_prefix}-gke-pods"    // Must match secondary range name in VPC
  ip_range_services_name       = "${local.env_prefix}-gke-services" // Must match secondary range name in VPC
  release_channel              = var.gke_release_channel
  kubernetes_version           = var.gke_kubernetes_version
  labels                       = local.global_labels
  node_pools                   = local.gke_node_pools_processed
  enable_private_nodes         = true
  enable_private_endpoint      = true                             // Master endpoint is private
  master_ipv4_cidr_block       = var.gke_master_ipv4_cidr_block // Required for private endpoint
  master_authorized_networks   = local.gke_master_auth_networks_combined
  enable_network_policy        = var.gke_enable_network_policy
  enable_workload_identity     = var.gke_enable_workload_identity
  database_encryption_key      = var.gke_database_encryption_key
  node_pools_oauth_scopes = { # Default OAuth scopes for node pools
    all = [
      "https://www.googleapis.com/auth/cloud-platform", # Broad scope, consider narrowing
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/trace.append",
    ]
  }
  node_pools_labels = { # Default labels for node pools, merged with individual pool labels
    all = local.global_labels
  }
  node_pools_tags = { # Default tags for node pools, merged with individual pool tags
    all = ["${local.env_prefix}-gke-node"]
  }
}

// --- Database (Cloud SQL PostgreSQL) Module ---
module "database" {
  source = "../../modules/database"

  project_id            = local.project_id
  name_suffix           = var.db_instance_name_suffix
  name_prefix           = local.env_prefix
  region                = local.region
  database_version      = var.db_database_version
  tier                  = var.db_tier
  availability_type     = var.db_availability_type
  disk_type             = var.db_disk_type
  disk_size_gb          = var.db_disk_size_gb
  db_name               = var.db_name
  db_user_name          = var.db_user
  db_user_password_secret_id = var.db_user_password_secret_id
  vpc_network_self_link = module.vpc.network_self_link // For private IP configuration
  labels                = local.global_labels
  backup_config = {
    enabled                        = true
    start_time                     = "03:00" # UTC
    location                       = local.region
    retained_backups               = var.db_backup_retention_count
    transaction_log_retention_days = var.db_backup_retention_count # For PITR
  }
  point_in_time_recovery_enabled = var.db_point_in_time_recovery_enabled
  db_flags                       = var.db_flags

  # Authorized networks for private IP are controlled by VPC firewall rules.
  # If public IP were enabled, this would be used:
  # authorized_networks = [
  #   {
  #     name  = "bastion-access"
  #     value = module.bastion.bastion_public_ip # Example
  #   }
  # ]
}

// --- ALB Module ---
module "alb" {
  source = "../../modules/alb"

  project_id         = local.project_id
  name_prefix        = "${local.env_prefix}-alb-${var.alb_name_suffix}"
  domain_names       = [var.alb_domain_name] # Module expects a list
  network_name       = module.vpc.network_name
  labels             = local.global_labels
  backend_negs       = var.alb_gke_negs
  health_check_path  = var.alb_health_check_path
  create_static_ip   = true
  # ssl_policy         = "MODERN" # Optional: specify a preconfigured SSL policy or create one
  cloud_armor_policy_self_link = var.alb_cloud_armor_policy_name != null ? "projects/${local.project_id}/global/securityPolicies/${var.alb_cloud_armor_policy_name}" : null

  depends_on = [module.gke] # Ensure GKE is up, though NEGs are the real dependency
}