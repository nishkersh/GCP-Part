locals {
  # Find subnet details by name for NAT configuration
  subnet_self_links_map = { for snet in google_compute_subnetwork.custom_subnets : snet.name => snet.self_link }
  subnet_details_map    = { for snet_config in var.subnets : snet_config.name => snet_config }

  nat_subnetwork_configs = [
    for nat_snet_config in var.nat_subnetworks : {
      name                     = local.subnet_self_links_map[nat_snet_config.name]
      source_ip_ranges_to_nat  = nat_snet_config.source_ip_ranges_to_nat
      secondary_ip_range_names = lookup(nat_snet_config, "secondary_ip_range_names", null)
    } if contains(keys(local.subnet_self_links_map), nat_snet_config.name) # Ensure subnet exists
  ]
}

resource "google_compute_network" "custom_vpc" {
  project                 = var.project_id
  name                    = var.network_name
  auto_create_subnetworks = var.auto_create_subnetworks
  routing_mode            = var.routing_mode
  mtu                     = var.mtu
  delete_default_routes_on_create = var.delete_default_internet_gateway_routes

  dynamic "log_config" {
    for_each = var.enable_flow_logs && var.flow_logs_config != null ? [var.flow_logs_config] : []
    content {
      aggregation_interval = log_config.value.aggregation_interval
      flow_sampling        = log_config.value.flow_sampling
      metadata             = log_config.value.metadata
      filter_expr          = log_config.value.filter_expr
    }
  }


}

resource "google_compute_subnetwork" "custom_subnets" {
  for_each = { for subnet in var.subnets : subnet.name => subnet }

  project                  = var.project_id
  name                     = each.value.name
  ip_cidr_range            = each.value.ip_cidr_range
  network                  = google_compute_network.custom_vpc.self_link
  region                   = each.value.region
  description              = each.value.description
  private_ip_google_access = each.value.private_ip_google_access
  purpose                  = each.value.purpose
  role                     = each.value.role

  dynamic "secondary_ip_range" {
    for_each = each.value.secondary_ip_ranges != null ? each.value.secondary_ip_ranges : {}
    content {
      range_name    = secondary_ip_range.key
      ip_cidr_range = secondary_ip_range.value
    }
  }

  dynamic "log_config" {
    for_each = each.value.log_config != null ? [each.value.log_config] : []
    content {
      aggregation_interval = log_config.value.aggregation_interval
      flow_sampling        = log_config.value.flow_sampling
      metadata             = log_config.value.metadata
      filter_expr          = log_config.value.filter_expr
      metadata_fields      = log_config.value.metadata_fields
    }
  }
  // The 'labels' attribute is not a supported argument for the google_compute_subnetwork resource.
  // Labels can be applied to the parent google_compute_network (which uses var.labels in this configuration)
  // or to individual resources deployed within the subnet, but not directly to the subnet resource itself.
}

// --- Default Firewall Rules ---
// GCP implicitly adds a deny-all ingress and allow-all egress rule if no other rules match.
// We will add explicit rules for clarity and control.

resource "google_compute_firewall" "default_deny_all_ingress" {
  project  = var.project_id
  name     = "${var.network_name}-deny-all-ingress"
  network  = google_compute_network.custom_vpc.self_link
  priority = 65534 // Low priority, applies if nothing else matches

  direction = "INGRESS"
  deny {
    protocol = "all"
  }
  source_ranges = ["0.0.0.0/0"] // Applies to all sources
  description   = "Default deny all ingress traffic unless explicitly allowed by higher priority rules."

}

resource "google_compute_firewall" "default_allow_all_egress" {
  project  = var.project_id
  name     = "${var.network_name}-allow-all-egress" // Standard GCP behavior
  network  = google_compute_network.custom_vpc.self_link
  priority = 65534 // Low priority

  direction = "EGRESS"
  allow {
    protocol = "all"
  }
  destination_ranges = ["0.0.0.0/0"]
  description        = "Default allow all egress traffic. Outbound traffic should be controlled by NAT and specific deny rules if needed."

}

resource "google_compute_firewall" "allow_internal" {
  project  = var.project_id
  name     = "${var.network_name}-allow-internal"
  network  = google_compute_network.custom_vpc.self_link
  priority = 65500 // Higher than default deny, lower than specific allows

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = [for snet in var.subnets : snet.ip_cidr_range] # Allow from all defined subnets within the VPC
  description   = "Allow all internal traffic within the VPC network."
 
}

// --- Custom Firewall Rules ---
resource "google_compute_firewall" "custom_rules" {
  for_each = { for rule in var.firewall_rules : rule.name => rule }

  project     = var.project_id
  name        = each.value.name
  network     = google_compute_network.custom_vpc.self_link
  description = each.value.description
  direction   = upper(each.value.direction)
  priority    = each.value.priority
  disabled    = each.value.disabled

  dynamic "allow" {
    for_each = each.value.allow != null ? each.value.allow : []
    content {
      protocol = allow.value.protocol
      ports    = lookup(allow.value, "ports", null)
    }
  }

  dynamic "deny" {
    for_each = each.value.deny != null ? each.value.deny : []
    content {
      protocol = deny.value.protocol
      ports    = lookup(deny.value, "ports", null)
    }
  }

  source_ranges           = each.value.direction == "INGRESS" ? each.value.ranges : null
  destination_ranges      = each.value.direction == "EGRESS" ? each.value.ranges : null
  source_tags             = each.value.source_tags
  source_service_accounts = each.value.source_service_accounts
  target_tags             = each.value.target_tags
  target_service_accounts = each.value.target_service_accounts

  dynamic "log_config" {
    for_each = each.value.log_config != null ? [each.value.log_config] : []
    content {
      metadata = log_config.value.metadata
    }
  }

}


// --- Cloud NAT Configuration (Optional) ---
resource "google_compute_router" "nat_router" {
  count   = var.enable_cloud_nat && length(local.nat_subnetwork_configs) > 0 ? 1 : 0
  project = var.project_id
  name    = "${var.network_name}-${var.nat_router_name}"
  network = google_compute_network.custom_vpc.self_link
  region  = var.region
}

resource "google_compute_router_nat" "nat_gateway" {
  count   = var.enable_cloud_nat && length(local.nat_subnetwork_configs) > 0 ? 1 : 0
  project = var.project_id
  name    = "${var.network_name}-${var.nat_gateway_name}"
  router  = google_compute_router.nat_router[0].name
  region  = var.region

  nat_ip_allocate_option = var.nat_ip_allocate_option
  nat_ips                = var.nat_ip_allocate_option == "MANUAL_ONLY" ? var.nat_manual_addresses : null

  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS" # Required when specifying subnetwork blocks

  dynamic "subnetwork" {
    for_each = local.nat_subnetwork_configs
    content {
      name                     = subnetwork.value.name # This is the self_link from local.nat_subnetwork_configs
      source_ip_ranges_to_nat  = subnetwork.value.source_ip_ranges_to_nat
      secondary_ip_range_names = subnetwork.value.secondary_ip_range_names
    }
  }

  # Default: UDP_IDLE_TIMEOUT_SEC = 30, TCP_ESTABLISHED_IDLE_TIMEOUT_SEC = 1200, TCP_TRANSITORY_IDLE_TIMEOUT_SEC = 30
  # min_ports_per_vm = 64 (default)
  # max_ports_per_vm = 65536

  log_config {
    enable = true                # Enable logging for NAT
    filter = "ERRORS_ONLY"       # Log only errors, or "TRANSLATIONS_ONLY", "ALL"
  }
}
