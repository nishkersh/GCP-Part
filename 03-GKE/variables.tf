variable "project_id" {
  description = "The GCP project ID."
  type        = string
}

variable "name" {
  description = "The name of the GKE cluster."
  type        = string
  validation {
    condition     = length(var.name) <= 40 && can(regex("^[a-z]([-a-z0-9]*[a-z0-9])?$", var.name))
    error_message = "GKE cluster name must be 1-40 characters, start with a letter, and contain only lowercase letters, numbers, or hyphens."
  }
}

variable "description" {
  description = "The description of the GKE cluster."
  type        = string
  default     = "GKE cluster managed by Terraform"
}

variable "region" {
  description = "The GCP region for the GKE cluster."
  type        = string
}

variable "locations" {
  description = "The list of zones in which the cluster's nodes are located. Nodes are created in all listed zones. If null, the cluster's default zone setting for the region will be used."
  type        = list(string)
  default     = null # For regional clusters, GKE will pick zones. Can be specified for finer control.
}

variable "network_name" {
  description = "The name of the VPC network to which the GKE cluster will be connected."
  type        = string
}

variable "subnetwork_name" {
  description = "The name of the subnetwork to which the GKE cluster will be connected."
  type        = string
}

variable "ip_range_pods_name" {
  description = "The name of the secondary IP range for GKE pods in the subnetwork."
  type        = string
}

variable "ip_range_services_name" {
  description = "The name of the secondary IP range for GKE services in the subnetwork."
  type        = string
}

variable "kubernetes_version" {
  description = "The Kubernetes version for the GKE cluster (e.g., '1.27.5-gke.200'). If null, the default version for the release channel is used."
  type        = string
  default     = null
}

variable "release_channel" {
  description = "The release channel of the GKE cluster (RAPID, REGULAR, STABLE, or UNSPECIFIED)."
  type        = string
  default     = "REGULAR"
  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE", "UNSPECIFIED"], var.release_channel)
    error_message = "Invalid GKE release channel."
  }
}

variable "enable_private_nodes" {
  description = "Whether GKE nodes should have public IP addresses. True for private nodes."
  type        = bool
  default     = true
}

variable "enable_private_endpoint" {
  description = "Whether the GKE master should have a private endpoint. Requires master_ipv4_cidr_block."
  type        = bool
  default     = true
}

variable "enable_public_endpoint" {
  description = "Whether the GKE master should have a public endpoint. If both private and public are true, both are enabled. If private is true and public is false, only private endpoint is available."
  type        = bool
  default     = false # For fully private cluster, set to false. If true with private_endpoint=true, public endpoint is accessible via authorized networks.
}

variable "master_ipv4_cidr_block" {
  description = "The /28 CIDR block for the GKE master's internal IP range. Required if enable_private_endpoint is true."
  type        = string
  default     = null
  validation {
    condition     = var.enable_private_endpoint == false || (var.enable_private_endpoint == true && var.master_ipv4_cidr_block != null && can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/28$", var.master_ipv4_cidr_block)))
    error_message = "master_ipv4_cidr_block must be a valid /28 CIDR if private endpoint is enabled."
  }
}

variable "master_authorized_networks" {
  description = "Map of display names to CIDR blocks for GKE master authorized networks. Applied if public endpoint is enabled or if private endpoint needs access from outside VPC."
  type        = map(string)
  default     = {}
  # Example: { "office_vpn" = "203.0.113.0/24" }
}

variable "enable_network_policy" {
  description = "Enable network policy (e.g., Calico) on the GKE cluster."
  type        = bool
  default     = true
}

variable "network_policy_provider" {
  description = "Network policy provider (CALICO or GKE_DATA_PATH_V2 for Cilium). If null and enable_network_policy is true, CALICO is used."
  type        = string
  default     = "CALICO"
  validation {
    condition     = contains(["CALICO", "PROVIDER_UNSPECIFIED", null], var.network_policy_provider) # GKE_DATA_PATH_V2 is set via enable_dataplane_v2
    error_message = "Invalid network_policy_provider. Must be CALICO or null (PROVIDER_UNSPECIFIED)."
  }
}

variable "enable_dataplane_v2" {
  description = "Enable Dataplane V2 (based on Cilium and eBPF) for advanced networking features. If true, network_policy_provider is ignored and GKE_DATA_PATH_V2 is used."
  type        = bool
  default     = false # Consider setting to true for new clusters for better performance and features.
}

variable "enable_workload_identity" {
  description = "Enable Workload Identity on the GKE cluster."
  type        = bool
  default     = true
}

variable "workload_identity_pool" {
  description = "The workload identity pool to use. Defaults to PROJECT_ID.svc.id.goog. If null, it will be computed."
  type        = string
  default     = null
}

variable "database_encryption_key" {
  description = "Optional: The self-link of the KMS key for GKE application-layer secrets encryption (etcd encryption). e.g., projects/PROJECT_ID/locations/REGION/keyRings/KEYRING_NAME/cryptoKeys/KEY_NAME"
  type        = string
  default     = null
}

variable "logging_service" {
  description = "The logging service to use (e.g., 'logging.googleapis.com/kubernetes' for Cloud Logging)."
  type        = string
  default     = "logging.googleapis.com/kubernetes"
}

variable "monitoring_service" {
  description = "The monitoring service to use (e.g., 'monitoring.googleapis.com/kubernetes' for Cloud Monitoring)."
  type        = string
  default     = "monitoring.googleapis.com/kubernetes"
}

variable "enable_shielded_nodes" {
  description = "Enable Shielded GKE Nodes for all node pools by default."
  type        = bool
  default     = true
}

variable "initial_node_count" {
  description = "The number of nodes to create in the default GKE node pool. Only used if `node_pools` variable is empty."
  type        = number
  default     = 1
  validation {
    condition     = var.initial_node_count >= 0 # 0 is valid for node-less clusters (e.g. Autopilot) or if node_pools are defined.
    error_message = "Initial node count must be non-negative."
  }
}

variable "remove_default_node_pool" {
  description = "Whether to remove the default node pool after cluster creation. Useful if you exclusively use `node_pools`."
  type        = bool
  default     = false # Set to true if you define all your node pools in var.node_pools
}

variable "node_pools" {
  description = "A map of GKE node pool configurations. Key is the node pool name suffix."
  type = map(object({
    name_prefix          = optional(string) # If not set, uses map key
    node_count           = optional(number) # Initial node count per zone for this pool
    min_node_count       = optional(number) # Min nodes per zone for autoscaling
    max_node_count       = optional(number) # Max nodes per zone for autoscaling
    total_min_node_count = optional(number) # Min total nodes for autoscaling (regional)
    total_max_node_count = optional(number) # Max total nodes for autoscaling (regional)
    autoscaling          = optional(bool, true)
    location_policy      = optional(string, "ANY") # BALANCED or ANY (for regional cluster node pool zone distribution)
    node_locations       = optional(list(string))  # Specific zones for this node pool, overrides cluster locations for this pool
    machine_type         = optional(string, "e2-medium")
    disk_size_gb         = optional(number, 100)
    disk_type            = optional(string, "pd-standard") # e.g., pd-standard, pd-ssd
    image_type           = optional(string, "COS_CONTAINERD")
    service_account      = optional(string) # Email of an existing SA. If null, a new one is created per pool.
    oauth_scopes         = optional(list(string))
    preemptible          = optional(bool, false)
    spot                 = optional(bool, false) # GCE Spot VMs. If true, preemptible is ignored.
    tags                 = optional(list(string), [])
    labels               = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string # NO_SCHEDULE, PREFER_NO_SCHEDULE, NO_EXECUTE
    })), [])
    max_pods_per_node      = optional(number) # Default is 110
    enable_shielded_nodes  = optional(bool)   # Overrides cluster default
    boot_disk_kms_key    = optional(string) # CMEK for node boot disks
  }))
  default = {}
}

variable "node_pools_oauth_scopes" {
  description = "Default OAuth scopes for all node pools. Can be overridden per node pool."
  type = map(list(string))
  default = {
    # Default set of scopes for GKE nodes
    all = [
      "https://www.googleapis.com/auth/devstorage.read_only", # Needed for pulling images from GCR/GAR
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",          # Includes .write and .read
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/trace.append"
    ]
    # Example: e2-medium = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

variable "node_pools_labels" {
  description = "Default labels for all node pools. Merged with and can be overridden by individual node pool labels."
  type        = map(map(string))
  default     = { all = {} }
}

variable "node_pools_tags" {
  description = "Default tags for all node pools. Merged with and can be overridden by individual node pool tags."
  type        = map(list(string))
  default     = { all = [] }
}

variable "node_pools_service_account_roles" {
  description = "Default IAM roles to assign to newly created node pool service accounts."
  type        = list(string)
  default = [
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/logging.logWriter",
    "roles/stackdriver.resourceMetadata.writer", # For metadata to Ops Suite
    # "roles/artifactregistry.reader" # Add if pulling images from Artifact Registry
  ]
}

variable "maintenance_policy_window" {
  description = "Maintenance window for the GKE cluster (e.g., 'MM-DDTHH:MM:SSZ' in RFC3339 format, or daily/weekly specifications)."
  type        = string
  default     = null # GKE default if null
  # Example for daily: "03:00" (UTC)
  # Example for specific window: "2024-01-01T02:00:00Z" with recurrence "FREQ=WEEKLY;BYDAY=SA"
}

variable "labels" {
  description = "A map of labels to apply to the GKE cluster itself."
  type        = map(string)
  default     = {}
}

variable "cluster_resource_labels" {
  description = "The GCE resource labels (key/value pairs) to be applied to the cluster."
  type        = map(string)
  default     = {}
}

variable "enable_vertical_pod_autoscaling" {
  description = "Enable Vertical Pod Autoscaling (VPA) for the cluster."
  type        = bool
  default     = true
}

variable "enable_intranode_visibility" {
  description = "Enable Intranode visibility for GKE cluster."
  type        = bool
  default     = false # Can increase log volume
}

variable "default_max_pods_per_node" {
  description = "The default maximum number of pods per node in the cluster. Node pools can override this."
  type        = number
  default     = 110
}

variable "authenticator_security_group" {
  description = "The RBAC security group for use with Google security groups in Kubernetes RBAC. Group name must be in format gke-security-groups@yourdomain.com"
  type        = string
  default     = null
}

variable "private_cluster_config" {
  description = "Configuration for private cluster."
  type = object({
    enable_private_nodes    = optional(bool) # Redundant with top-level var.enable_private_nodes
    enable_private_endpoint = optional(bool) # Redundant with top-level var.enable_private_endpoint
    master_ipv4_cidr_block  = optional(string) # Redundant with top-level var.master_ipv4_cidr_block
    master_global_access_enabled = optional(bool, false) # Allows master to be globally accessible within the VPC network
  })
  default = {} # Values will be taken from top-level variables if not set here
}

variable "addons_config" {
  description = "Configuration for GKE add-ons."
  type = object({
    http_load_balancing = optional(object({
      disabled = bool
    }), { disabled = false }) # Enabled by default
    horizontal_pod_autoscaling = optional(object({
      disabled = bool
    }), { disabled = false }) # Enabled by default
    network_policy_config = optional(object({ # This is for the legacy NetworkPolicy addon, prefer enable_network_policy
      disabled = bool
    }))
    # Other addons like Istio, ConfigConnector, etc. can be added here
    # Example:
    # istio_config = optional(object({
    #   disabled = bool
    #   auth     = optional(string) # "AUTH_MUTUAL_TLS" or "AUTH_NONE"
    # }))
    # config_connector_config = optional(object({
    #   enabled = bool
    # }))
  })
  default = {}
}