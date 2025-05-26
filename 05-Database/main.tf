locals {
  instance_name = "${var.name_prefix}-sql-${var.name_suffix}"

  # Determine private network self-link
  private_network_self_link = coalesce(var.ip_configuration.private_network, var.vpc_network_self_link)

  # Default backup configuration
  backup_config_defaults = {
    enabled                        = true
    start_time                     = "03:00"
    location                       = null # Defaults to instance region
    retained_backups               = 7
    transaction_log_retention_days = 7    # For PITR
  }
  final_backup_config = merge(local.backup_config_defaults, var.backup_config)

  # Point-in-time recovery for PostgreSQL is enabled by having transaction_log_retention_days > 0
  # and binary_log_enabled for MySQL.
  pitr_enabled_pg = local.final_backup_config.enabled && local.final_backup_config.transaction_log_retention_days > 0
  # For MySQL, binary_log_enabled must also be true. This module focuses on PG, so this is simpler.
  final_pitr_enabled = var.point_in_time_recovery_enabled && local.pitr_enabled_pg

  # IP configuration merging defaults
  ip_config_defaults = {
    ipv4_enabled    = false # Default to no public IP
    private_network = local.private_network_self_link
    allocated_ip_range = null
    require_ssl     = true
  }
  final_ip_configuration = merge(local.ip_config_defaults, var.ip_configuration, {
    # Ensure private_network is correctly set if derived from vpc_network_self_link
    private_network = local.private_network_self_link
  })

  # Ensure private IP is enabled if private_network is specified
  enable_private_ip = local.final_ip_configuration.private_network != null
}

// --- Fetch Database User Password from Secret Manager ---
data "google_secret_manager_secret_version" "db_user_password" {
  secret = split("/", var.db_user_password_secret_id)[3] # Extract secret name
  project = split("/", var.db_user_password_secret_id)[1] # Extract project from secret_id
  # version = split("/", var.db_user_password_secret_id)[5] # Extract version if not 'latest'
  # If version is 'latest', provider handles it.
}
/*
  **IMPORTANT: Secret Management for Database Password**
  The database user password is fetched from Google Secret Manager.
  You MUST create the secret and its version before applying this Terraform configuration.

  Example gcloud commands:
  1. Create the secret:
     `gcloud secrets create "${var.db_user_name}-password" --project="${var.project_id}" --replication-policy="automatic"`
     (Replace var.db_user_name and var.project_id with actual values or use a more generic secret name)

  2. Add a secret version with the password:
     `echo -n "YOUR_STRONG_PASSWORD" | gcloud secrets versions add "${var.db_user_name}-password" --project="${var.project_id}" --data-file=-`

  3. Ensure the Terraform service account has the 'Secret Manager Secret Accessor' role (`roles/secretmanager.secretAccessor`)
     on this specific secret or the project.

  Update `var.db_user_password_secret_id` in your .tfvars file to point to this secret, e.g.:
  `db_user_password_secret_id = "projects/YOUR_PROJECT_ID/secrets/YOUR_SECRET_NAME/versions/latest"`
*/


// --- Cloud SQL Instance ---
resource "google_sql_database_instance" "instance" {
  project             = var.project_id
  name                = local.instance_name
  region              = var.region
  database_version    = var.database_version
  deletion_protection = var.deletion_protection

  settings {
    tier    = var.tier
    activation_policy = var.activation_policy
    availability_type = var.availability_type # ZONAL or REGIONAL

    disk_autoresize       = var.disk_autoresize
    disk_autoresize_limit = var.disk_autoresize_limit
    disk_size             = var.disk_size_gb
    disk_type             = var.disk_type

    backup_configuration {
      enabled                        = local.final_backup_config.enabled
      start_time                     = local.final_backup_config.start_time
      location                       = local.final_backup_config.location
      retained_backups               = local.final_backup_config.retained_backups
      transaction_log_retention_days = local.final_backup_config.transaction_log_retention_days # For PITR
      point_in_time_recovery_enabled = local.final_pitr_enabled
    }

    ip_configuration {
      ipv4_enabled     = local.final_ip_configuration.ipv4_enabled
      private_network  = local.enable_private_ip ? local.final_ip_configuration.private_network : null
      allocated_ip_range = local.enable_private_ip ? local.final_ip_configuration.allocated_ip_range : null
      require_ssl      = local.final_ip_configuration.require_ssl
      dynamic "authorized_networks" {
        for_each = local.final_ip_configuration.ipv4_enabled ? var.authorized_networks : []
        content {
          name  = authorized_networks.value.name
          value = authorized_networks.value.value
          expiration_time = lookup(authorized_networks.value, "expiration_time", null)
        }
      }
    }

    database_flags {
      name  = each.key
      value = each.value
      for_each = var.db_flags
    }

    labels = var.labels # Instance-level labels

    dynamic "maintenance_window" {
      for_each = var.maintenance_window_day != null && var.maintenance_window_hour != null ? [1] : []
      content {
        day   = var.maintenance_window_day
        hour  = var.maintenance_window_hour
        update_track = "stable" # Or "canary"
      }
    }

    insights_config {
      query_insights_enabled      = var.insights_config_query_insights_enabled
      query_string_length         = var.insights_config_query_string_length
      record_application_tags     = var.insights_config_record_application_tags
      record_client_address       = var.insights_config_record_client_address
    }

    # location_preference { # For zonal instances
    #   zone = "${var.region}-a" # Example, make configurable if needed
    # }
  }

  # Ensure the Service Networking API is enabled and private service connection exists
  # This is often handled by the google_service_networking_connection resource in the VPC setup
  # or needs to be done once per project per network.
  # Adding a depends_on here if that resource is in another module can be tricky.
  # It's usually better to ensure it's created beforehand or as part of VPC setup.

  # For PostgreSQL, PITR is enabled if transaction_log_retention_days > 0.
  # For MySQL, binary_log_enabled must be true. This is implicitly handled by setting
  # transaction_log_retention_days for PG.
}

// --- Initial Database ---
resource "google_sql_database" "initial_db" {
  project  = var.project_id
  instance = google_sql_database_instance.instance.name
  name     = var.db_name
  charset  = var.db_charset != "" ? var.db_charset : null # null lets provider use default
  collation = var.db_collation != "" ? var.db_collation : null # null lets provider use default
}

// --- Initial User ---
resource "google_sql_user" "initial_user" {
  project  = var.project_id
  instance = google_sql_database_instance.instance.name
  name     = var.db_user_name
  password = data.google_secret_manager_secret_version.db_user_password.secret_data # Fetched from Secret Manager
  # host field can be used to restrict user access from specific hosts, e.g. "%" for any host.
  # For PostgreSQL, type can be CLOUD_IAM_USER or CLOUD_IAM_SERVICE_ACCOUNT for IAM authentication.
  # type = "BUILT_IN" (default)
}

// --- Private Service Access Connection (if not handled elsewhere) ---
// This resource is typically configured once per VPC network per project.
// It's often placed in the VPC module or a foundational networking setup.
// If you ensure it's created before this module runs, you might not need it here.
/*
resource "google_compute_global_address" "private_service_access_ip" {
  count = local.enable_private_ip && var.ip_configuration.allocated_ip_range == null ? 1 : 0 # Create if private IP and no custom range

  project       = var.project_id
  name          = "${replace(local.instance_name, "-", "")}-psa-range" # Must be unique
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = "192.168.255.0" # Example, pick a non-overlapping /24 range
  prefix_length = 24
  network       = local.final_ip_configuration.private_network
}

resource "google_service_networking_connection" "private_service_access" {
  count = local.enable_private_ip ? 1 : 0

  network                 = local.final_ip_configuration.private_network
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [
    var.ip_configuration.allocated_ip_range != null ? var.ip_configuration.allocated_ip_range : google_compute_global_address.private_service_access_ip[0].name
  ]

  depends_on = [google_compute_global_address.private_service_access_ip]
}

// The Cloud SQL instance depends on this connection being active.
// Add to google_sql_database_instance.instance:
// depends_on = [google_service_networking_connection.private_service_access]
*/