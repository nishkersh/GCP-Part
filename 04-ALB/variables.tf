variable "project_id" {
  description = "The GCP project ID."
  type        = string
}

variable "name_prefix" {
  description = "A prefix for all resources created by this module (e.g., 'myapp-prod-lb')."
  type        = string
}

variable "network_name" {
  description = "The name of the VPC network. Used for context but ALB is global."
  type        = string
}

variable "domain_names" {
  description = "A list of domain names for which Google-managed SSL certificates will be created and associated with the load balancer."
  type        = list(string)
  validation {
    condition     = length(var.domain_names) > 0
    error_message = "At least one domain name must be provided."
  }
}

variable "create_static_ip" {
  description = "If true, a global static IP address will be reserved for the load balancer."
  type        = bool
  default     = true
}

variable "static_ip_name" {
  description = "Name for the global static IP address if create_static_ip is true."
  type        = string
  default     = "frontend-ip" # Will be prefixed by name_prefix
}

variable "existing_static_ip_address_self_link" {
  description = "Self-link of an existing global static IP address to use. If set, create_static_ip is ignored."
  type        = string
  default     = null
}

variable "backend_negs" {
  description = <<EOT
A list of objects describing backend Network Endpoint Groups (NEGs).
These are typically GKE service NEGs (standalone NEGs).
Example: [{
  neg_name      = "k8s1-xxxxxxxx-namespace-service-8080-neg" (The actual NEG name from GKE)
  neg_zone      = "us-central1-a" (Zone of the NEG for zonal NEGs)
  # neg_region    = "us-central1" (Region for regional NEGs, if applicable)
  port_name     = "http" (Optional: A friendly name for the port, used in URL map path matcher)
  service_port  = 8080   (Optional: The port on the NEG backends, for reference or if needed by health check)
  balancing_mode = "RATE" # Or CONNECTION
  max_rate_per_endpoint = 100 # Required if balancing_mode is RATE
  # capacity_scaler (0.0-1.0)
}]
EOT
  type = list(object({
    neg_name              = string
    neg_zone              = optional(string) # For zonal NEGs (most common for GKE services)
    neg_region            = optional(string) # For regional NEGs
    port_name             = optional(string, "default-port")
    service_port          = optional(number, 80) # Used for health check default if not overridden
    balancing_mode        = optional(string, "RATE")
    max_rate_per_endpoint = optional(number) # Required for RATE mode
    max_connections_per_endpoint = optional(number) # Required for CONNECTION mode
    capacity_scaler       = optional(number, 1.0)
  }))
  default = []
}

variable "default_backend_service_name" {
  description = "Name for the default backend service in the URL map."
  type        = string
  default     = "default-backend" # Will be prefixed
}

variable "default_health_check_name" {
  description = "Name for the default health check."
  type        = string
  default     = "default-hc" # Will be prefixed
}

variable "health_check_path" {
  description = "The request path for the health check."
  type        = string
  default     = "/"
}

variable "health_check_port" {
  description = "The port for the health check. If null, uses the port from the first backend NEG."
  type        = number
  default     = null
}

variable "health_check_protocol" {
  description = "Protocol for the health check (HTTP, HTTPS, HTTP2, TCP, SSL)."
  type        = string
  default     = "HTTP"
}

variable "health_check_interval_sec" {
  description = "How often (in seconds) to send a health check."
  type        = number
  default     = 15
}

variable "health_check_timeout_sec" {
  description = "How long (in seconds) to wait before claiming failure."
  type        = number
  default     = 5
}

variable "health_check_unhealthy_threshold" {
  description = "A so-far healthy instance will be marked unhealthy after this many consecutive failures."
  type        = number
  default     = 3
}

variable "health_check_healthy_threshold" {
  description = "A so-far unhealthy instance will be marked healthy after this many consecutive successes."
  type        = number
  default     = 2
}

variable "backend_service_port_name" {
  description = "The port name of the backend service. This is an arbitrary name used to identify the port on the backends."
  type        = string
  default     = "http" # Should match the port name in GKE service if applicable
}

variable "backend_service_protocol" {
  description = "The protocol for the backend service (HTTP, HTTPS, HTTP2, TCP, SSL, GRPC)."
  type        = string
  default     = "HTTP" # Traffic from LB to backend. For GKE NEGs, usually HTTP.
}

variable "backend_service_timeout_sec" {
  description = "Timeout for the backend service in seconds."
  type        = number
  default     = 30
}

variable "enable_cdn" {
  description = "Enable Cloud CDN for the default backend service."
  type        = bool
  default     = false
}

variable "cdn_policy_cache_mode" {
  description = "CDN cache mode (CACHE_ALL_STATIC, USE_ORIGIN_HEADERS, FORCE_CACHE_ALL)."
  type        = string
  default     = "CACHE_ALL_STATIC"
}

variable "cdn_policy_default_ttl" {
  description = "Default TTL for CDN cached content in seconds."
  type        = number
  default     = 3600
}

variable "ssl_policy" {
  description = "Optional: Self-link of an existing SSL policy to attach to the HTTPS proxy. If null, GCP default is used."
  type        = string
  default     = null # e.g., "projects/PROJECT_ID/global/sslPolicies/your-ssl-policy"
}

variable "quic_override" {
  description = "QUIC policy for the target HTTPS proxy (NONE, ENABLE, DISABLE)."
  type        = string
  default     = "NONE" # Or "ENABLE" if your backends support HTTP/3 & QUIC
}

variable "url_map_name" {
  description = "Name for the URL map."
  type        = string
  default     = "url-map" # Will be prefixed
}

variable "target_https_proxy_name" {
  description = "Name for the Target HTTPS Proxy."
  type        = string
  default     = "https-proxy" # Will be prefixed
}

variable "forwarding_rule_name" {
  description = "Name for the Global Forwarding Rule."
  type        = string
  default     = "https-forwarding-rule" # Will be prefixed
}

variable "enable_logging" {
  description = "Enable logging for the backend service. If true, a sample rate of 1.0 (100%) is used."
  type        = bool
  default     = true
}

variable "logging_sample_rate" {
  description = "Logging sample rate for the backend service (0.0 to 1.0). Only used if enable_logging is true."
  type        = number
  default     = 1.0
  validation {
    condition     = var.logging_sample_rate >= 0.0 && var.logging_sample_rate <= 1.0
    error_message = "Logging sample rate must be between 0.0 and 1.0."
  }
}

variable "cloud_armor_policy_self_link" {
  description = "Optional: Self-link of a Cloud Armor security policy to attach to the default backend service."
  type        = string
  default     = null # e.g., "projects/PROJECT_ID/global/securityPolicies/your-armor-policy"
}

variable "labels" {
  description = "A map of labels to apply to all resources created by this module."
  type        = map(string)
  default     = {}
}

variable "http_to_https_redirect" {
  description = "If true, creates an additional HTTP load balancer to redirect HTTP traffic to HTTPS."
  type        = bool
  default     = true # Common best practice
}

variable "http_forwarding_rule_name" {
  description = "Name for the HTTP Global Forwarding Rule if redirect is enabled."
  type        = string
  default     = "http-redirect-forwarding-rule" # Will be prefixed
}

variable "http_target_proxy_name" {
  description = "Name for the HTTP Target Proxy if redirect is enabled."
  type        = string
  default     = "http-redirect-proxy" # Will be prefixed
}

variable "http_url_map_name" {
  description = "Name for the HTTP URL map if redirect is enabled."
  type        = string
  default     = "http-redirect-url-map" # Will be prefixed
}