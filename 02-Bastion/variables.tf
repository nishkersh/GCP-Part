variable "project_id" {
  description = "The GCP project ID where the bastion host will be created."
  type        = string
}

variable "zone" {
  description = "The GCP zone for the bastion host instance."
  type        = string
}

variable "name_prefix" {
  description = "A prefix for the bastion host name and related resources."
  type        = string
  default     = "bastion-host"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name_prefix))
    error_message = "Name prefix must be lowercase alphanumeric with hyphens."
  }
}

variable "machine_type" {
  description = "The machine type for the bastion host instance."
  type        = string
  default     = "e2-micro"
}

variable "boot_disk_size_gb" {
  description = "The size of the boot disk in GB."
  type        = number
  default     = 20
}

variable "boot_disk_type" {
  description = "The type of the boot disk (e.g., pd-standard, pd-ssd)."
  type        = string
  default     = "pd-standard"
}

variable "source_image_family" {
  description = "Source image family for the boot disk (e.g., debian-11). If source_image is set, this is ignored."
  type        = string
  default     = "debian-11"
}

variable "source_image_project" {
  description = "Project where the source image family belongs (e.g., debian-cloud). If source_image is set, this is ignored."
  type        = string
  default     = "debian-cloud"
}

variable "source_image" {
  description = "Optional: Specific source image for the boot disk (e.g., projects/debian-cloud/global/images/debian-11-bullseye-v20230101). Overrides family/project."
  type        = string
  default     = null
}

variable "network_name" {
  description = "The name of the VPC network to deploy the bastion host into."
  type        = string
}

variable "subnet_name" {
  description = "The name of the subnetwork to deploy the bastion host into."
  type        = string
}

variable "create_static_external_ip" {
  description = "If true, a static external IP address will be created and assigned to the bastion."
  type        = bool
  default     = true
}

variable "external_ip_address_name" {
  description = "Name for the static external IP address resource, if created."
  type        = string
  default     = "bastion-external-ip" # Will be prefixed by name_prefix
}

variable "service_account_email" {
  description = "Optional: Email of an existing service account to attach to the bastion. If null, a new one is created."
  type        = string
  default     = null
}

variable "service_account_name" {
  description = "Name for the dedicated service account if one is created for the bastion."
  type        = string
  default     = "bastion-sa" # Will be prefixed by name_prefix
}

variable "service_account_roles" {
  description = "List of IAM roles to assign to the bastion's service account. Defaults provide minimal necessary permissions."
  type        = list(string)
  default = [
    "roles/compute.osLogin",             # Allows SSH via OS Login
    "roles/monitoring.metricWriter",     # Allows writing metrics for observability
    "roles/logging.logWriter",           # Allows writing logs
    "roles/iam.serviceAccountUser"       # Allows instance to act as the SA (implicitly added but good to be explicit)
  ]
}

variable "tags" {
  description = "A list of network tags to apply to the bastion host instance. Used for firewall rules."
  type        = list(string)
  default     = ["bastion-host"] # Generic tag, environment-specific prefixing done in root module
}

variable "labels" {
  description = "A map of labels to apply to the bastion host and related resources."
  type        = map(string)
  default     = {}
}

variable "enable_shielded_vm" {
  description = "Enable Shielded VM features: Secure Boot, vTPM, Integrity Monitoring."
  type        = bool
  default     = true
}

variable "startup_script" {
  description = "Startup script to run when the instance is launched."
  type        = string
  default     = null # Example: "#!/bin/bash\napt-get update\napt-get install -y qemu-guest-agent"
}

variable "deletion_protection" {
  description = "Whether the instance is protected from accidental deletion."
  type        = bool
  default     = false # Set to true for production bastions
}