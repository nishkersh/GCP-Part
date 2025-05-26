locals {
  cluster_name = var.name
  network_self_link = "projects/${var.project_id}/global/networks/${var.network_name}"
  subnetwork_self_link = "projects/${var.project_id}/regions/${var.region}/subnetworks/${var.subnetwork_name}"

  effective_workload_identity_pool = coalesce(var.workload_identity_pool, "${var.project_id}.svc.id.goog")

  # Private cluster specific configurations
  private_cluster_config_merged = {
    enable_private_nodes         = var.enable_private_nodes
    enable_private_endpoint      = var.enable_private_endpoint
    master_ipv4_cidr_block       = var.master_ipv4_cidr_block
    master_global_access_enabled = lookup(var.private_cluster_config, "master_global_access_enabled", false)
    # peering_name: GKE manages this automatically for private clusters
  }

  # Addons configuration merging defaults
  addons_config_final = {
    http_load_balancing = {
      disabled = lookup(var.addons_config.http_load_balancing, "disabled", false)
    }
    horizontal_pod_autoscaling = {
      disabled = lookup(var.addons_config.horizontal_pod_autoscaling, "disabled", false)
    }
    # If network_policy_config is explicitly set in var.addons_config, use it.
    # Otherwise, derive from var.enable_network_policy.
    network_policy_config = var.addons_config.network_policy_config != null ? {
      disabled = var.addons_config.network_policy_config.disabled
      } : {
      disabled = !var.enable_network_policy # If enable_network_policy is true, addon should not be disabled.
    }
    # Merge other addons if provided
    # istio_config = var.addons_config.istio_config
    # config_connector_config = var.addons_config.config_connector_config
  }

  # Network policy configuration
  network_policy = var.enable_network_policy ? {
    enabled  = true
    provider = var.enable_dataplane_v2 ? "PROVIDER_UNSPECIFIED" : var.network_policy_provider # Dataplane V2 implies its own provider
    } : {
    enabled  = false
    provider = "PROVIDER_UNSPECIFIED"
  }

  # Default node pool is created if no custom node pools are defined and remove_default_node_pool is false
  create_default_node_pool = length(var.node_pools) == 0 && !var.remove_default_node_pool && var.initial_node_count > 0
}

resource "google_container_cluster" "primary" {
  project                  = var.project_id
  name                     = local.cluster_name
  location                 = var.region # For regional clusters, location is the region
  description              = var.description
  initial_node_count       = local.create_default_node_pool ? var.initial_node_count : null # Only if creating default pool
  remove_default_node_pool = var.remove_default_node_pool || length(var.node_pools) > 0 # Remove if custom pools are defined or explicitly told to

  network    = local.network_self_link
  subnetwork = local.subnetwork_self_link

  # Node locations for regional cluster. If null, GKE picks zones in the region.
  node_locations = var.locations

  # IP Allocation Policy
  ip_allocation_policy {
    cluster_secondary_range_name  = var.ip_range_pods_name
    services_secondary_range_name = var.ip_range_services_name
  }

  # Master version and release channel
  min_master_version = var.kubernetes_version # If null, release_channel default is used
  release_channel {
    channel = var.release_channel
  }

  # Security
  enable_shielded_nodes = var.enable_shielded_nodes # Default for node pools unless overridden

  # Workload Identity
  workload_identity_config {
    workload_pool = local.effective_workload_identity_pool
  }

  # Application-layer Secrets Encryption (etcd encryption)
  dynamic "database_encryption" {
    for_each = var.database_encryption_key != null ? [1] : []
    content {
      state    = "ENCRYPTED"
      key_name = var.database_encryption_key
    }
  }
  # Example for var.database_encryption_key:
  # "projects/YOUR_PROJECT_ID/locations/YOUR_REGION/keyRings/YOUR_KEYRING/cryptoKeys/YOUR_KEY"
  # Ensure the GKE service account (service-<PROJECT_NUMBER>@container-engine-robot.iam.gserviceaccount.com)
  # has the "Cloud KMS CryptoKey Encrypter/Decrypter" role on the specified key.

  # Logging and Monitoring
  logging_service    = var.logging_service
  monitoring_service = var.monitoring_service

  # Private Cluster Configuration
  private_cluster_config {
    enable_private_nodes         = local.private_cluster_config_merged.enable_private_nodes
    enable_private_endpoint      = local.private_cluster_config_merged.enable_private_endpoint
    master_ipv4_cidr_block       = local.private_cluster_config_merged.master_ipv4_cidr_block
    master_global_access_config {
      enabled = local.private_cluster_config_merged.master_global_access_enabled
    }
  }

  # Public endpoint access control (if public endpoint is enabled)
  dynamic "master_authorized_networks_config" {
    for_each = var.enable_public_endpoint || (var.enable_private_endpoint && length(var.master_authorized_networks) > 0) ? [true] : []
    content {
      dynamic "cidr_blocks" {
        for_each = var.master_authorized_networks
        content {
          display_name = cidr_blocks.key
          cidr_block   = cidr_blocks.value
        }
      }
    }
  }

  # Network Policy
  network_policy {
    enabled  = local.network_policy.enabled
    provider = local.network_policy.provider
  }

  # Dataplane V2
  datapath_provider = var.enable_dataplane_v2 ? "ADVANCED_DATAPATH" : "DATAPATH_PROVIDER_UNSPECIFIED"

  # Addons
  addons_config {
    http_load_balancing {
      disabled = local.addons_config_final.http_load_balancing.disabled
    }
    horizontal_pod_autoscaling {
      disabled = local.addons_config_final.horizontal_pod_autoscaling.disabled
    }
    network_policy_config { # This refers to the legacy addon, not the main network_policy block
      disabled = local.addons_config_final.network_policy_config.disabled
    }
    # istio_config = local.addons_config_final.istio_config
    # config_connector_config = local.addons_config_final.config_connector_config
  }

  # Maintenance Policy
  dynamic "maintenance_policy" {
    for_each = var.maintenance_policy_window != null ? [1] : []
    content {
      # Daily window example: "03:00"
      # Specific window example:
      # recurring_window {
      #   start_time = "2024-01-01T02:00:00Z"
      #   end_time   = "2024-01-01T06:00:00Z"
      #   recurrence = "FREQ=WEEKLY;BYDAY=SA"
      # }
      daily_maintenance_window {
        start_time = var.maintenance_policy_window # Assuming daily format if simple string
      }
    }
  }

  # Vertical Pod Autoscaling
  vertical_pod_autoscaling {
    enabled = var.enable_vertical_pod_autoscaling
  }

  # Intranode Visibility
  enable_intranode_visibility = var.enable_intranode_visibility

  # Default max pods per node
  default_max_pods_per_node = var.default_max_pods_per_node

  # Authenticator security group for RBAC
  dynamic "authenticator_groups_config" {
    for_each = var.authenticator_security_group != null ? [1] : []
    content {
      security_group = var.authenticator_security_group
    }
  }

  # Labels
  resource_labels         = var.cluster_resource_labels # For underlying GCE instances
  deletion_protection     = false                     # Set to true for production clusters

  # If default node pool is used and no custom pools, configure it here.
  # This is mostly superseded by google_container_node_pool resources for better management.
  # node_config {
  #   # ... if not using separate node_pool resources and not removing default pool
  # }

  lifecycle {
    ignore_changes = [
      # Ignore changes to node_pool if managing them separately or if initial_node_count is used only for creation.
      node_pool,
      initial_node_count, # If you scale node pools manually or via autoscaler after creation
    ]
  }
}

// --- Node Pools ---

// Service Accounts for Node Pools
resource "google_service_account" "node_pool_sa" {
  for_each = {
    for k, v in var.node_pools : k => v if v.service_account == null # Create SA only if not provided
  }
  project      = var.project_id
  account_id   = substr(replace(lower("${local.cluster_name}-${each.key}-np-sa"), "_", "-"), 0, 30)
  display_name = "GKE Node Pool SA for ${local.cluster_name} / ${each.key}"
}

resource "google_project_iam_member" "node_pool_sa_roles" {
  for_each = {
    for item in flatten([
      for sa_key, sa_config in var.node_pools :
      [
        for role in var.node_pools_service_account_roles :
        {
          sa_key   = sa_key,
          sa_config = sa_config,
          role     = role
        }
        if sa_config.service_account == null # Only for SAs created by this module
      ]
    ]) :
    "${item.sa_key}-${item.role}" => {
      sa_email = google_service_account.node_pool_sa[item.sa_key].email
      role     = item.role
    }
  }
  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${each.value.sa_email}"
}

// Actual Node Pools
resource "google_container_node_pool" "pools" {
  for_each = var.node_pools

  name       = each.value.name_prefix != null ? each.value.name_prefix : "${local.cluster_name}-${each.key}"
  project    = var.project_id
  location   = var.region # For regional clusters, location is the region. For zonal, it's the zone.
  cluster    = google_container_cluster.primary.name

  # Node count and autoscaling
  initial_node_count = lookup(each.value, "node_count", null) # Per zone if regional
  # If autoscaling is enabled, node_count is initial, min/max control scaling.
  # If autoscaling is disabled, node_count is the fixed number of nodes per zone.

  dynamic "autoscaling" {
    for_each = lookup(each.value, "autoscaling", true) ? [1] : []
    content {
      min_node_count       = lookup(each.value, "min_node_count", 0) # Per zone
      max_node_count       = lookup(each.value, "max_node_count", 3) # Per zone
      total_min_node_count = lookup(each.value, "total_min_node_count", null) # For regional cluster total
      total_max_node_count = lookup(each.value, "total_max_node_count", null) # For regional cluster total
      location_policy      = lookup(each.value, "location_policy", "ANY") # BALANCED or ANY
    }
  }
  # If autoscaling is false, and initial_node_count is not set, it might lead to issues.
  # Ensure initial_node_count is set if autoscaling is false.
  node_count = !lookup(each.value, "autoscaling", true) && lookup(each.value, "node_count", null) != null ? lookup(each.value, "node_count", 1) : null


  node_locations = lookup(each.value, "node_locations", null) # Specific zones for this node pool

  node_config {
    machine_type = lookup(each.value, "machine_type", "e2-medium")
    disk_size_gb = lookup(each.value, "disk_size_gb", 100)
    disk_type    = lookup(each.value, "disk_type", "pd-standard")
    image_type   = lookup(each.value, "image_type", "COS_CONTAINERD")

    service_account = lookup(each.value, "service_account", google_service_account.node_pool_sa[each.key].email) # Use created or provided SA

    oauth_scopes = distinct(concat(
      lookup(var.node_pools_oauth_scopes, each.key, []),
      lookup(var.node_pools_oauth_scopes, "all", []),
      lookup(each.value, "oauth_scopes", [])
    ))

    preemptible = lookup(each.value, "spot", false) ? false : lookup(each.value, "preemptible", false) # Spot takes precedence
    spot        = lookup(each.value, "spot", false)

    labels = merge(
      lookup(var.node_pools_labels, "all", {}),
      lookup(var.node_pools_labels, each.key, {}),
      lookup(each.value, "labels", {})
    )
    tags = distinct(concat(
      lookup(var.node_pools_tags, "all", []),
      lookup(var.node_pools_tags, each.key, []),
      lookup(each.value, "tags", [])
    ))

    dynamic "taint" {
      for_each = lookup(each.value, "taints", [])
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }

    shielded_instance_config {
      enable_secure_boot          = lookup(each.value, "enable_shielded_nodes", var.enable_shielded_nodes)
      enable_integrity_monitoring = lookup(each.value, "enable_shielded_nodes", var.enable_shielded_nodes)
      # vTPM is implicitly enabled with shielded nodes in GKE
    }

    boot_disk_kms_key = lookup(each.value, "boot_disk_kms_key", null)
    # metadata = {
    #   disable-legacy-endpoints = "true"
    # }
  }

  max_pods_per_node = lookup(each.value, "max_pods_per_node", var.default_max_pods_per_node)

  management {
    auto_repair  = true
    auto_upgrade = true # Recommended for security and stability
  }

  upgrade_settings {
    max_surge       = 1 # Number of additional nodes that can be added during an upgrade
    max_unavailable = 0 # Number of nodes that can be simultaneously unavailable during an upgrade
    # strategy: BLUE_GREEN or SURGE (default)
  }

  depends_on = [google_service_account.node_pool_sa, google_project_iam_member.node_pool_sa_roles]
}