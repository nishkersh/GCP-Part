data "google_compute_image" "os_image" {
  count   = var.source_image == null ? 1 : 0 # Only lookup if specific image not provided
  family  = var.source_image_family
  project = var.source_image_project
}

locals {
  image = var.source_image != null ? var.source_image : data.google_compute_image.os_image[0].self_link

  # Construct full names with prefix
  instance_name         = "${var.name_prefix}-vm"
  address_name          = var.create_static_external_ip ? "${var.name_prefix}-${var.external_ip_address_name}" : null
  service_account_id    = substr(replace(lower("${var.name_prefix}-${var.service_account_name}"), "_", "-"), 0, 30) # Max 30 chars, specific format
  service_account_email_final = var.service_account_email != null ? var.service_account_email : google_service_account.bastion_sa[0].email
}

resource "google_compute_address" "static_ip" {
  count   = var.create_static_external_ip ? 1 : 0
  project = var.project_id
  name    = local.address_name
  region  = substr(var.zone, 0, length(var.zone) - 2) # Extract region from zone
  labels  = var.labels
}

resource "google_service_account" "bastion_sa" {
  count        = var.service_account_email == null ? 1 : 0 # Create SA only if not provided
  project      = var.project_id
  account_id   = local.service_account_id
  display_name = "Bastion Host Service Account for ${var.name_prefix}"
  description  = "Service Account for bastion host ${var.name_prefix}, managed by Terraform."
}

resource "google_project_iam_member" "bastion_sa_roles" {
  for_each = var.service_account_email == null ? toset(var.service_account_roles) : toset([]) # Assign roles only if SA is created by module
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.bastion_sa[0].email}"
}

resource "google_compute_instance" "bastion_host" {
  project      = var.project_id
  zone         = var.zone
  name         = local.instance_name
  machine_type = var.machine_type
  tags         = var.tags
  labels       = var.labels
  description  = "Bastion Host instance managed by Terraform."

  boot_disk {
    initialize_params {
      image = local.image
      size  = var.boot_disk_size_gb
      type  = var.boot_disk_type
    }
  }

  network_interface {
    subnetwork = "projects/${var.project_id}/regions/${substr(var.zone, 0, length(var.zone) - 2)}/subnetworks/${var.subnet_name}"
    # network    = var.network_name # Subnetwork implies network

    dynamic "access_config" {
      for_each = var.create_static_external_ip ? [1] : [] # Create access_config if static IP is used
      content {
        nat_ip = google_compute_address.static_ip[0].address
      }
    }
    # If create_static_external_ip is false, an ephemeral IP will be assigned by default.
    # To have no external IP, an empty access_config {} block would be needed,
    # but a bastion typically needs an external IP.
  }

  service_account {
    email  = local.service_account_email_final
    scopes = ["cloud-platform"] # Broad scope, actual permissions controlled by IAM roles on SA
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  dynamic "shielded_instance_config" {
    for_each = var.enable_shielded_vm ? [1] : []
    content {
      enable_secure_boot          = true
      enable_vtpm                 = true
      enable_integrity_monitoring = true
    }
  }

  metadata = {
    startup-script = var.startup_script
    # Enable OS Login for all project users or specific users/groups
    # This is generally preferred over SSH keys in metadata for better IAM integration.
    # Ensure OS Login API is enabled on the project.
    enable-oslogin = "TRUE"
  }

  allow_stopping_for_update = true # Allows Terraform to update certain fields by stopping/starting
  deletion_protection       = var.deletion_protection

  lifecycle {
    create_before_destroy = true # Useful if IP needs to be preserved on recreation, though static IP handles this better
  }

  depends_on = [
    google_service_account.bastion_sa,
    google_project_iam_member.bastion_sa_roles
  ]
}