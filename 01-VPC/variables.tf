variable "project_id" {
  description = "The GCP project ID."
  type        = string
}

variable "network_name" {
  description = "The name of the VPC network."
  type        = string
  validation {
    condition     = length(var.network_name) <= 63 && can(regex("^[a-z]([-a-z0-9]*[a-z0-9])?$", var.network_name))
    error_message = "Network name must be 1-63 characters, start with a letter, and contain only lowercase letters, numbers, or hyphens."
  }
}

variable "region" {
  description = "The GCP region where subnets and regional resources will be created."
  type        = string
}

variable "routing_mode" {
  description = "The network routing mode (REGIONAL or GLOBAL)."
  type        = string
  default     = "REGIONAL"
  validation {
    condition     = contains(["REGIONAL", "GLOBAL"], var.routing_mode)
    error_message = "Routing mode must be REGIONAL or GLOBAL."
  }
}

variable "auto_create_subnetworks" {
  description = "When set to true, a subnet will be created in each region automatically. When set to false, you must create subnets manually. This module assumes false (custom mode)."
  type        = bool
  default     = false
}

variable "delete_default_internet_gateway_routes" {
  description = "If set, ensure that all routes within the network specified whose names begin with 'default-route' and with a next hop of 'default-internet-gateway' are deleted."
  type        = bool
  default     = false # Set to true if you want to ensure no default route to internet exists before NAT.
}

variable "mtu" {
  description = "Maximum Transmission Unit in bytes. The default value is 1460 bytes. The minimum value for MTU is 1300 bytes and the maximum value is 8896 bytes (jumbo frames)."
  type        = number
  default     = 1460
  validation {
    condition     = var.mtu >= 1300 && var.mtu <= 8896
    error_message = "MTU must be between 1300 and 8896."
  }
}

variable "subnets" {
  description = "A list of subnet configurations to create."
  type = list(object({
    name                     = string
    ip_cidr_range            = string
    region                   = string # Should match module's region for regional subnets
    description              = optional(string, "Managed by Terraform")
    private_ip_google_access = optional(bool, false)
    purpose                  = optional(string, "PRIVATE") # e.g., PRIVATE, PRIVATE_SERVICE_CONNECT, PRIVATE_GKE_CONTAINER_SUBNET
    role                     = optional(string)            # e.g., ACTIVE, BACKUP (for GKE alias IP subnets)
    secondary_ip_ranges      = optional(map(string), {})  # map of range_name = cidr_block
    log_config = optional(object({
      aggregation_interval = optional(string)
      flow_sampling        = optional(number)
      metadata             = optional(string)
      filter_expr          = optional(string)
      metadata_fields      = optional(list(string))
    }), null) # Optional: enable flow logs per subnet
  }))
  default = []
}

variable "firewall_rules" {
  description = "A list of custom firewall rule configurations."
  type = list(object({
    name                    = string
    description             = optional(string, "Managed by Terraform")
    direction               = optional(string, "INGRESS")
    priority                = optional(number, 1000)
    disabled                = optional(bool, false)
    ranges                  = optional(list(string)) # For INGRESS: source_ranges; for EGRESS: destination_ranges
    source_tags             = optional(list(string))
    source_service_accounts = optional(list(string))
    target_tags             = optional(list(string))
    target_service_accounts = optional(list(string))
    allow = optional(list(object({
      protocol = string
      ports    = optional(list(string))
    })), [])
    deny = optional(list(object({
      protocol = string
      ports    = optional(list(string))
    })), [])
    log_config = optional(object({
      metadata = string # "INCLUDE_ALL_METADATA" or "EXCLUDE_ALL_METADATA"
    }), null)
  }))
  default = []
}

variable "enable_cloud_nat" {
  description = "Flag to enable Cloud NAT for selected subnets."
  type        = bool
  default     = true
}

variable "nat_router_name" {
  description = "Name for the Cloud Router used by NAT."
  type        = string
  default     = "nat-router" # Will be prefixed
}

variable "nat_gateway_name" {
  description = "Name for the Cloud NAT Gateway."
  type        = string
  default     = "nat-gateway" # Will be prefixed
}

variable "nat_ip_allocate_option" {
  description = "NAT IP allocation option (AUTO_ONLY or MANUAL_ONLY)."
  type        = string
  default     = "AUTO_ONLY"
}

variable "nat_manual_addresses" {
  description = "List of self-links of regional static IP addresses to use for NAT if nat_ip_allocate_option is MANUAL_ONLY."
  type        = list(string)
  default     = []
}

variable "nat_subnetworks" {
  description = "List of subnets to configure for NAT. Each object should specify subnet name and IP ranges to NAT."
  type = list(object({
    name                    = string # Name of the subnet (must match one from var.subnets)
    source_ip_ranges_to_nat = list(string) # e.g., ["ALL_IP_RANGES"], ["PRIMARY_IP_RANGE"], ["LIST_OF_SECONDARY_IP_RANGES"]
    secondary_ip_range_names = optional(list(string)) # Required if source_ip_ranges_to_nat is LIST_OF_SECONDARY_IP_RANGES
  }))
  default = []
}

variable "enable_flow_logs" {
  description = "Enable VPC flow logs for the network. Individual subnets can override this."
  type        = bool
  default     = true
}

variable "flow_logs_config" {
  description = "Configuration for VPC flow logs if enabled at the network level."
  type = object({
    aggregation_interval = optional(string, "INTERVAL_5_SEC")
    flow_sampling        = optional(number, 0.5)
    metadata             = optional(string, "INCLUDE_ALL_METADATA")
    filter_expr          = optional(string, "true") # Default is to log all traffic
  })
  default = {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
    filter_expr          = "true"
  }
  nullable = true
}

variable "labels" {
  description = "A map of labels to apply to all resources created by this module."
  type        = map(string)
  default     = {}
}