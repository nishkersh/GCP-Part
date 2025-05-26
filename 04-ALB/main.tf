locals {
  full_static_ip_name             = "${var.name_prefix}-${var.static_ip_name}"
  full_default_health_check_name  = "${var.name_prefix}-${var.default_health_check_name}"
  full_default_backend_svc_name = "${var.name_prefix}-${var.default_backend_service_name}"
  full_url_map_name               = "${var.name_prefix}-${var.url_map_name}"
  full_target_https_proxy_name    = "${var.name_prefix}-${var.target_https_proxy_name}"
  full_forwarding_rule_name       = "${var.name_prefix}-${var.forwarding_rule_name}"
  managed_ssl_cert_name           = replace("${var.name_prefix}-cert-${var.domain_names[0]}", ".", "-") # Sanitize for resource name

  # For HTTP redirect
  full_http_forwarding_rule_name = "${var.name_prefix}-${var.http_forwarding_rule_name}"
  full_http_target_proxy_name    = "${var.name_prefix}-${var.http_target_proxy_name}"
  full_http_url_map_name         = "${var.name_prefix}-${var.http_url_map_name}"

  # Determine IP address to use
  ip_address_self_link = var.existing_static_ip_address_self_link != null ? var.existing_static_ip_address_self_link : (
    var.create_static_ip ? google_compute_global_address.default[0].self_link : null
  )
  ip_address_value = var.existing_static_ip_address_self_link != null ? var.existing_static_ip_address_self_link : ( # This should be the IP value, not self_link for forwarding rule
    var.create_static_ip ? google_compute_global_address.default[0].address : null # null means ephemeral
  )

  # Backend NEGs configuration
  backend_service_backends = [
    for neg_config in var.backend_negs : {
      group = (neg_config.neg_zone != null ?
        "projects/${var.project_id}/zones/${neg_config.neg_zone}/networkEndpointGroups/${neg_config.neg_name}" :
      "projects/${var.project_id}/regions/${neg_config.neg_region}/networkEndpointGroups/${neg_config.neg_name}")
      balancing_mode               = neg_config.balancing_mode
      max_rate_per_endpoint        = neg_config.balancing_mode == "RATE" ? lookup(neg_config, "max_rate_per_endpoint", 100) : null
      max_connections_per_endpoint = neg_config.balancing_mode == "CONNECTION" ? lookup(neg_config, "max_connections_per_endpoint", null) : null
      capacity_scaler              = lookup(neg_config, "capacity_scaler", 1.0)
    }
  ]

  health_check_port_final = var.health_check_port != null ? var.health_check_port : (
    length(var.backend_negs) > 0 ? var.backend_negs[0].service_port : 80 # Default to 80 if no NEGs or port specified
  )
}

// --- Global Static IP Address (Optional) ---
resource "google_compute_global_address" "default" {
  count   = var.create_static_ip && var.existing_static_ip_address_self_link == null ? 1 : 0
  project = var.project_id
  name    = local.full_static_ip_name
  labels  = var.labels
}

// --- Managed SSL Certificate ---
resource "google_compute_managed_ssl_certificate" "default" {
  project = var.project_id
  name    = local.managed_ssl_cert_name
  managed {
    domains = var.domain_names
  }
  labels = var.labels
  # lifecycle {
  #   create_before_destroy = true # May be needed if domains change often
  # }
}

// --- Health Check ---
resource "google_compute_health_check" "default" {
  project = var.project_id
  name    = local.full_default_health_check_name
  timeout_sec        = var.health_check_timeout_sec
  check_interval_sec = var.health_check_interval_sec
  healthy_threshold    = var.health_check_healthy_threshold
  unhealthy_threshold  = var.health_check_unhealthy_threshold

  dynamic "http_health_check" {
    for_each = upper(var.health_check_protocol) == "HTTP" ? [1] : []
    content {
      port         = local.health_check_port_final
      request_path = var.health_check_path
    }
  }
  dynamic "https_health_check" {
    for_each = upper(var.health_check_protocol) == "HTTPS" ? [1] : []
    content {
      port         = local.health_check_port_final
      request_path = var.health_check_path
    }
  }
  dynamic "http2_health_check" {
    for_each = upper(var.health_check_protocol) == "HTTP2" ? [1] : []
    content {
      port         = local.health_check_port_final
      request_path = var.health_check_path
    }
  }
  dynamic "tcp_health_check" {
    for_each = upper(var.health_check_protocol) == "TCP" ? [1] : []
    content {
      port = local.health_check_port_final
    }
  }
  dynamic "ssl_health_check" {
    for_each = upper(var.health_check_protocol) == "SSL" ? [1] : []
    content {
      port = local.health_check_port_final
    }
  }
  labels = var.labels
}

// --- Backend Service ---
resource "google_compute_backend_service" "default" {
  project = var.project_id
  name    = local.full_default_backend_svc_name
  protocol              = var.backend_service_protocol
  port_name             = var.backend_service_port_name
  timeout_sec           = var.backend_service_timeout_sec
  enable_cdn            = var.enable_cdn
  load_balancing_scheme = "EXTERNAL_MANAGED" # For Global HTTP(S) LB

  dynamic "backend" {
    for_each = local.backend_service_backends
    content {
      group                        = backend.value.group
      balancing_mode               = backend.value.balancing_mode
      max_rate_per_endpoint        = backend.value.max_rate_per_endpoint
      max_connections_per_endpoint = backend.value.max_connections_per_endpoint
      capacity_scaler              = backend.value.capacity_scaler
    }
  }

  health_checks = [google_compute_health_check.default.self_link]

  dynamic "cdn_policy" {
    for_each = var.enable_cdn ? [1] : []
    content {
      cache_mode                   = var.cdn_policy_cache_mode
      default_ttl                  = var.cdn_policy_default_ttl
      client_ttl                   = null # Can be configured
      max_ttl                      = null # Can be configured
      negative_caching             = false
      serve_while_stale            = null # In seconds
      signed_url_cache_max_age_sec = null
    }
  }

  dynamic "log_config" {
    for_each = var.enable_logging ? [1] : []
    content {
      enable      = true
      sample_rate = var.logging_sample_rate
    }
  }

  security_policy = var.cloud_armor_policy_self_link
  labels          = var.labels
}

// --- URL Map ---
resource "google_compute_url_map" "default" {
  project = var.project_id
  name    = local.full_url_map_name
  default_service = google_compute_backend_service.default.self_link
  # Can add path_matchers and host_rules here for advanced routing
  labels = var.labels
}

// --- Target HTTPS Proxy ---
resource "google_compute_target_https_proxy" "default" {
  project = var.project_id
  name    = local.full_target_https_proxy_name
  url_map = google_compute_url_map.default.self_link
  ssl_certificates = [google_compute_managed_ssl_certificate.default.self_link]
  ssl_policy       = var.ssl_policy
  quic_override    = var.quic_override
  labels           = var.labels
}

// --- Global Forwarding Rule (HTTPS) ---
resource "google_compute_global_forwarding_rule" "https" {
  project = var.project_id
  name    = local.full_forwarding_rule_name
  target  = google_compute_target_https_proxy.default.self_link
  port_range = "443"
  ip_address = local.ip_address_value # Uses reserved IP or ephemeral if null
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_protocol           = "TCP"
  labels                = var.labels
}


// --- HTTP to HTTPS Redirect (Optional) ---
resource "google_compute_url_map" "http_redirect" {
  count   = var.http_to_https_redirect ? 1 : 0
  project = var.project_id
  name    = local.full_http_url_map_name
  default_url_redirect {
    https_redirect         = true
    strip_query            = false
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT" # 301
  }
  labels = var.labels
}

resource "google_compute_target_http_proxy" "http_redirect" {
  count   = var.http_to_https_redirect ? 1 : 0
  project = var.project_id
  name    = local.full_http_target_proxy_name
  url_map = google_compute_url_map.http_redirect[0].self_link
  labels  = var.labels
}

resource "google_compute_global_forwarding_rule" "http" {
  count   = var.http_to_https_redirect ? 1 : 0
  project = var.project_id
  name    = local.full_http_forwarding_rule_name
  target  = google_compute_target_http_proxy.http_redirect[0].self_link
  port_range = "80"
  ip_address = local.ip_address_value # Use the same IP as HTTPS for redirect
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_protocol           = "TCP"
  labels                = var.labels
}