output "network_name" {
  description = "The name of the VPC network."
  value       = google_compute_network.custom_vpc.name
}

output "network_id" {
  description = "The ID of the VPC network."
  value       = google_compute_network.custom_vpc.id
}

output "network_self_link" {
  description = "The self-link of the VPC network."
  value       = google_compute_network.custom_vpc.self_link
}

output "subnets" {
  description = "A map of subnet names to their details."
  value = {
    for snet in google_compute_subnetwork.custom_subnets :
    snet.name => {
      name                     = snet.name
      id                       = snet.id
      self_link                = snet.self_link
      ip_cidr_range            = snet.ip_cidr_range
      region                   = snet.region
      private_ip_google_access = snet.private_ip_google_access
      purpose                  = snet.purpose
      role                     = snet.role
      secondary_ip_ranges = [
        for range in coalesce(snet.secondary_ip_range, []) : {
          range_name    = range.range_name
          ip_cidr_range = range.ip_cidr_range
        }
      ]
    }
  }
}

output "subnets_details" {
  description = "A list of objects containing details for each created subnet."
  value = [
    for snet in google_compute_subnetwork.custom_subnets : {
      name                     = snet.name
      id                       = snet.id
      self_link                = snet.self_link
      ip_cidr_range            = snet.ip_cidr_range
      region                   = snet.region
      private_ip_google_access = snet.private_ip_google_access
      purpose                  = snet.purpose
      role                     = snet.role
      secondary_ip_ranges = [
        for range in coalesce(snet.secondary_ip_range, []) : {
          range_name    = range.range_name
          ip_cidr_range = range.ip_cidr_range
        }
      ]
    }
  ]
}


output "firewall_rules_created" {
  description = "Details of the custom firewall rules created."
  value       = { for k, v in google_compute_firewall.custom_rules : k => { name = v.name, self_link = v.self_link } }
}

output "nat_router_name" {
  description = "Name of the Cloud Router used for NAT, if created."
  value       = var.enable_cloud_nat && length(local.nat_subnetwork_configs) > 0 ? google_compute_router.nat_router[0].name : null
}

output "nat_gateway_name" {
  description = "Name of the Cloud NAT gateway, if created."
  value       = var.enable_cloud_nat && length(local.nat_subnetwork_configs) > 0 ? google_compute_router_nat.nat_gateway[0].name : null
}