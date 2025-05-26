variable "project_id" {
  description = "The GCP project ID."
  type        = string
}

variable "name_prefix" {
  description = "A prefix for the Cloud SQL instance name and related resources (e.g., 'myorg-env')."
  type        = string
}

variable "name_suffix" {
  description = "A suffix for the Cloud SQL instance name (e.g., 'main-pg'). The full name will be '{name_prefix}-sql-{name_suffix}'."
  type        = string
  default     = "main-pg"
}

variable "region" {
  description = "The GCP region for the Cloud SQL instance."
  type        = string
}

variable "database_version" {
  description = "The database engine version, e.g., POSTGRES_15, MYSQL_8_0."
  type        = string
  default     = "POSTGRES_15"
}

variable "tier" {
  description = "The machine type for the Cloud SQL instance (e.g., db-f1-micro, db-custom-2-7680)."
  type        = string
}

variable "activation_policy" {
  description = "The activation policy for the instance. Can be ALWAYS, NEVER or ON_DEMAND."
  type        = string
  default     = "ALWAYS"
}

variable "availability_type" {
  description = "The availability type of the Cloud SQL instance. Can be ZONAL or REGIONAL for HA."
  type        = string
  default     = "ZONAL" # Change to REGIONAL for production HA
  validation {
    condition     = contains(["ZONAL", "REGIONAL"], var.availability_type)
    error_message = "Availability type must be ZONAL or REGIONAL."
  }
}

variable "disk_autoresize" {
  description = "Whether to allow the disk to automatically resize."
  type        = bool
  default     = true
}

variable "disk_autoresize_limit" {
  description = "The maximum size to which the disk can be auto-resized, in GB. A value of 0 means no limit."
  type        = number
  default     = 0
}

variable "disk_size_gb" {
  description = "The size of the disk in GB."
  type        = number
  default     = 20
}

variable "disk_type" {
  description = "The type of data disk: PD_SSD or PD_HDD."
  type        = string
  default     = "PD_SSD"
}

variable "backup_config" {
  description = "Configuration for automated backups."
  type = object({
    enabled                        = optional(bool, true)
    start_time                     = optional(string, "03:00") # HH:MM format in UTC
    location                       = optional(string)          # GCS location for backups, defaults to instance region
    retained_backups               = optional(number, 7)
    transaction_log_retention_days = optional(number, 7) # For PITR, must be >= retained_backups for some dbs
  })
  default = {} # Defaults will be applied if not specified
}

variable "point_in_time_recovery_enabled" {
  description = "Enable point-in-time recovery (requires binary log enabled for MySQL, or specific settings for PostgreSQL)."
  type        = bool
  default     = true # For PostgreSQL, this is controlled by backup_config.transaction_log_retention_days
}

variable "ip_configuration" {
  description = "Configuration for IP addresses. Private IP is strongly recommended for production."
  type = object({
    ipv4_enabled    = optional(bool, true)  # Whether to assign a public IPv4 address
    private_network = optional(string)      # Self-link of the VPC network for private IP
    allocated_ip_range = optional(string)   # Name of the allocated IP range for private services access
    require_ssl     = optional(bool, true)  # Whether SSL is required for connections.
  })
  default = {
    ipv4_enabled = false # Default to no public IP
    require_ssl  = true
  }
}

variable "vpc_network_self_link" {
  description = "The self-link of the VPC network to use for private IP. Required if ip_configuration.private_network is not set and private IP is desired."
  type        = string
  default     = null
}

variable "db_name" {
  description = "The name of the initial database to create."
  type        = string
}

variable "db_charset" {
  description = "The character set for the initial database (e.g., UTF8 for PostgreSQL)."
  type        = string
  default     = "" # Let Cloud SQL use its default
}

variable "db_collation" {
  description = "The collation for the initial database (e.g., en_US.UTF8 for PostgreSQL)."
  type        = string
  default     = "" # Let Cloud SQL use its default
}

variable "db_user_name" {
  description = "The name for the initial database user."
  type        = string
}

variable "db_user_password_secret_id" {
  description = "The Secret Manager secret ID (format: projects/{project}/secrets/{secret}/versions/{version|latest}) for the database user's password. The module will fetch this secret."
  type        = string
  validation {
    condition     = can(regex("^projects/[^/]+/secrets/[^/]+/versions/[^/]+$", var.db_user_password_secret_id))
    error_message = "Invalid Secret Manager secret ID format. Must be 'projects/{project}/secrets/{secret}/versions/{version|latest}'."
  }
}

variable "db_flags" {
  description = "A map of database flags to set on the instance."
  type        = map(string)
  default     = {}
  # Example for PostgreSQL: { "log_min_duration_statement" = "250", "log_connections" = "on" }
}

variable "authorized_networks" {
  description = "List of authorized networks for public IP access. Each object has 'name' and 'value' (CIDR)."
  type = list(object({
    name  = string
    value = string
    expiration_time = optional(string)
  }))
  default = [] # Only relevant if public IP (ipv4_enabled=true) is used.
}

variable "deletion_protection" {
  description = "Whether the Cloud SQL instance should be protected from accidental deletion."
  type        = bool
  default     = true # Recommended for production
}

variable "labels" {
  description = "A map of labels to apply to the Cloud SQL instance."
  type        = map(string)
  default     = {}
}

variable "maintenance_window_day" {
  description = "The day of week (1-7, 1=Monday) for the maintenance window."
  type        = number
  default     = null # Let GCP pick
  validation {
    condition     = var.maintenance_window_day == null || (var.maintenance_window_day >= 1 && var.maintenance_window_day <= 7)
    error_message = "Maintenance window day must be between 1 and 7, or null."
  }
}

variable "maintenance_window_hour" {
  description = "The hour of day (0-23, UTC) for the maintenance window."
  type        = number
  default     = null # Let GCP pick
  validation {
    condition     = var.maintenance_window_hour == null || (var.maintenance_window_hour >= 0 && var.maintenance_window_hour <= 23)
    error_message = "Maintenance window hour must be between 0 and 23, or null."
  }
}

variable "insights_config_query_insights_enabled" {
  description = "True if Query Insights feature is enabled."
  type        = bool
  default     = true
}

variable "insights_config_query_string_length" {
  description = "Maximum query length stored in bytes. Between 256 and 4500. Default to 1024."
  type        = number
  default     = 1024
}

variable "insights_config_record_application_tags" {
  description = "True if Query Insights will record application tags from query comments."
  type        = bool
  default     = false
}

variable "insights_config_record_client_address" {
  description = "True if Query Insights will record client address when enabled."
  type        = bool
  default     = false
}