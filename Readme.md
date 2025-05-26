Act as an expert-level GCP Cloud Solutions Architect and Senior DevOps Engineer specializing in Terraform. Your task is to generate a comprehensive, production-grade Terraform project for provisioning a common set of foundational infrastructure services on Google Cloud Platform (GCP). This project will manage two distinct environments: `dev` and `production`.

**Core Project Principles:**

1.  **Extreme Modularity**:
    *   Design highly reusable, independent Terraform modules for each distinct GCP service or logical component.
    *   Each module must have a clear interface:
        *   `variables.tf`: Well-defined input variables with types, comprehensive descriptions, sensible default values (where applicable for non-environment-specific settings), and crucial input validation rules (e.g., for naming conventions, CIDR ranges).
        *   `outputs.tf`: Clearly defined outputs exposing essential resource attributes for inter-module dependencies or root module consumption.
    *   Modules should be self-contained and focused on a single responsibility.

2.  **Production-Grade Best Practices (Strict Adherence Required)**:
    *   **Security**:
        *   Secure-by-default configurations for all resources.
        *   Strict adherence to the principle of least privilege for all IAM roles and service accounts. Utilize well-scoped pre-defined GCP roles where practical to ensure security without excessive complexity. Custom IAM roles should only be considered if pre-defined roles are insufficient for achieving necessary least privilege.
        *   Robust network segmentation and private networking by default.
        *   Meticulously defined firewall rules (deny-all ingress by default, allow specific required traffic).
        *   Explicit guidance and Terraform code examples for managing secrets using Google Secret Manager (e.g., use `data "google_secret_manager_secret_version"` for database passwords, API keys, etc.). **Never hardcode sensitive values.**
    *   **Scalability**: Design resources for horizontal and vertical scalability (e.g., autoscaling GKE node pools, configurable instance types).
    *   **Reliability & High Availability**: Utilize regional resources, implement HA configurations (e.g., regional GKE, HA Cloud SQL), and configure health checks.
    *   **Cost-Effectiveness**: Suggest sensible, cost-conscious defaults for configurable parameters (e.g., `e2-micro` or `e2-small` for bastion, development environment instance types) but ensure all critical performance/cost parameters are configurable per environment. Implement comprehensive resource tagging for cost tracking and management.
    *   **Maintainability**:
        *   Generate clean, well-commented (explaining "why" for non-obvious choices), and idiomatic HCL.
        *   Employ consistent and predictable naming conventions for all resources (e.g., `gcp_project_id_prefix-${var.environment}-resource_type-specific_name`). Clearly state the chosen convention.
        *   Utilize `locals` for clarity, readability, and to avoid repetition.
    *   **Observability**: Enable and configure relevant logging and monitoring features for all services (e.g., VPC Flow Logs, GKE cluster logging/monitoring, Load Balancer logging, Cloud SQL audit and operational logs).

3.  **Multi-Environment Management (`dev`, `production`)**:
    *   **Root Directory Structure**:
        ```
        ├── environments/
        │   ├── dev/
        │   │   ├── main.tf
        │   │   ├── variables.tf
        │   │   ├── outputs.tf
        │   │   ├── backend.tf
        │   │   └── terraform.tfvars  // Example values for dev
        │   └── production/
        │       ├── main.tf
        │       ├── variables.tf
        │       ├── outputs.tf
        │       ├── backend.tf
        │       └── terraform.tfvars  // Example values for production
        ├── modules/
        │   ├── vpc/
        │   ├── bastion/
        │   ├── gke/
        │   ├── alb/
        │   └── database/
        ├── versions.tf             // Root provider & Terraform version constraints
        └── README.md               // Project overview, setup, module descriptions
        ```
    *   **Environment Configuration**:
        *   Each environment subdirectory (`environments/dev/`, `environments/production/`) will instantiate the required modules by sourcing them from the `../../modules/` directory.
        *   `backend.tf`: Configure to use a unique GCS bucket and prefix for remote Terraform state per environment (e.g., bucket `your-gcp-project-id-tfstate`, prefix `dev/` or `production/`). Make bucket name components configurable.
        *   `terraform.tfvars`: Provide *distinct example values* for `dev` and `production`, highlighting differences in instance sizes, replica counts, CIDR blocks, etc. Clearly indicate which variables are environment-specific.
    *   **Root `versions.tf`**: Specify required Google provider versions (e.g., `~> 5.0`) and Terraform engine version constraints (e.g., `~> 1.7`).

**Module Dependencies & Order of Creation (Informational for Design):**
1.  **VPC Module**: Independent base.
2.  **Bastion Module**: Depends on VPC module outputs (e.g., network name, public subnet name).
3.  **GKE Module**: Depends on VPC module outputs (e.g., network name, GKE subnet name) and potentially Bastion outputs (e.g., bastion's public IP for control plane authorized networks).
4.  **Database Module**: Depends on VPC module outputs (e.g., network name, database subnet name).
5.  **ALB Module**: Primarily depends on GKE module outputs (for Network Endpoint Group configuration related to GKE services) and VPC module outputs (for network context).

**Required Modules and Key Specifications:**

1.  **VPC Module (`modules/vpc`)**:
    *   **Key Resources**: `google_compute_network`, `google_compute_subnetwork`, `google_compute_firewall`, `google_compute_router`, `google_compute_router_nat`.
    *   **Requirements**:
        *   Custom-mode VPC.
        *   Subnets (configurable CIDRs, names, regions):
            *   `private-gke` (for GKE pods/services).
            *   `private-db` (for Cloud SQL).
            *   `public-bastion` (for Bastion Host).
        *   Essential Firewall Rules:
            *   Default deny all ingress.
            *   Allow internal traffic within the VPC on all ports/protocols.
            *   Allow SSH to `public-bastion` subnet/tagged instances from a configurable list of source IP CIDRs (placeholder provided).
            *   Allow GKE control plane to nodes communication (ports, direction).
            *   Allow egress to `0.0.0.0/0` from private subnets via Cloud NAT.
            *   Enable configuration of additional firewall rules passed as variables (e.g., for database access from GKE).
        *   Cloud NAT gateway for outbound internet access from all private subnets.
        *   Enable VPC Flow Logs with configurable aggregation interval and sampling.
    *   **Outputs**: VPC name, VPC self_link, subnet names, subnet self_links, subnet CIDRs, relevant network tags.

2.  **Bastion Server Module (`modules/bastion`)**:
    *   **Key Resources**: `google_compute_instance`, `google_compute_address` (for static IP).
    *   **Dependencies**: VPC module (for network, subnet).
    *   **Requirements**:
        *   Small, configurable GCE instance (e.g., `e2-micro` or `e2-small` default, `var.instance_type`).
        *   Deployed in the `public-bastion` subnet.
        *   Static public IP address.
        *   Firewall rule (defined in VPC module or referenced) allowing SSH *only* from specified source IP CIDRs (e.g., `var.ssh_source_cidrs`).
        *   Dedicated IAM Service Account using appropriate pre-defined roles for minimal permissions (e.g., OS Login, monitoring agent permissions if needed, no broader project access).
    *   **Outputs**: Bastion instance name, public IP, private IP, service account email.

3.  **GKE Cluster Module (`modules/gke`)**:
    *   **Key Resources**: `google_container_cluster`, `google_container_node_pool`.
    *   **Dependencies**: VPC module (for network, subnets), Bastion module (potentially for control plane authorized network IP).
    *   **Requirements**:
        *   Regional, **private** GKE cluster (nodes with no public IPs). Control plane endpoint access: Private or Public with tightly configured authorized networks.
        *   Control Plane Authorized Networks: Configurable list, including placeholder for Bastion's public IP and potentially other CIDRs.
        *   Enable and configure Workload Identity for secure pod access to GCP APIs.
        *   Enable Network Policy enforcement (e.g., Calico).
        *   Utilize `private-gke` subnet from VPC module for cluster nodes, pods, and services.
        *   At least one node pool:
            *   Configurable machine type, disk size/type, image type.
            *   Autoscaling enabled (min/max node count per zone).
            *   Dedicated IAM Service Account for nodes using appropriate pre-defined roles for minimal permissions (e.g., `roles/monitoring.metricWriter`, `roles/logging.logWriter`, `roles/artifactregistry.reader` if pulling images from GAR, specific GCS access if needed by workloads).
        *   Enable comprehensive cluster logging and monitoring to Google Cloud's Operations Suite (System, Workload, API server audit logs).
        *   Strongly recommend and provide commented-out example configuration (or clear instructions) for enabling etcd encryption using Customer-Managed Encryption Keys (CMEK) via `var.database_encryption_key`.
    *   **Outputs**: Cluster name, endpoint, CA certificate, node pool names, GKE service account email.

4.  **GCP HTTP(S) Load Balancer (ALB) Module (`modules/alb`)**:
    *   **Key Resources**: `google_compute_global_forwarding_rule`, `google_compute_target_https_proxy`, `google_compute_url_map`, `google_compute_backend_service`, `google_compute_health_check`, `google_compute_network_endpoint_group` (for GKE integration using standalone NEGs), `google_compute_managed_ssl_certificate`.
    *   **Dependencies**: GKE module (for GKE service NEG configuration inputs), VPC module (for network context).
    *   **Requirements**:
        *   Global HTTP(S) Load Balancer specifically configured to route traffic to GKE services.
        *   Frontend: Static global IP (provisioned or existing), Port 443.
        *   SSL: Google-managed SSL certificate for a configurable domain name (`var.domain_name`).
        *   Backend Service(s):
            *   Route traffic to GKE services using standalone Network Endpoint Groups (NEGs). The module should accept necessary inputs (e.g., NEG names or configurations derived from GKE service annotations) to link to these GKE-managed NEGs. Provide clear examples/stubs in comments or `README.md` for how GKE services should be annotated for NEG creation by GKE's NEG controller, and how this ALB module consumes that information.
            *   Configurable load balancing scheme, session affinity, timeout.
        *   Health Checks: Robust health checks for backend services.
        *   Enable comprehensive logging for the load balancer.
        *   Optional: Allow attachment of a Cloud Armor security policy (`var.cloud_armor_policy_name`).
    *   **Outputs**: LB IP address, managed SSL certificate name, backend service names.

5.  **GCP Database Module (Cloud SQL for PostgreSQL) (`modules/database`)**:
    *   **Key Resources**: `google_sql_database_instance`, `google_sql_database`, `google_sql_user`, `google_secret_manager_secret_version` (data source).
    *   **Dependencies**: VPC module (for network, private IP, firewall rule interaction).
    *   **Requirements**:
        *   Cloud SQL for PostgreSQL instance.
        *   High Availability (regional) configuration.
        *   Configurable instance tier (e.g., `db-custom-2-7680`), storage size/type, PostgreSQL version.
        *   **Private IP only**. Deployed in the `private-db` subnet.
        *   Enable automated backups and point-in-time recovery (configurable retention).
        *   Database flags configurable for production tuning (`var.db_flags`).
        *   Creation of at least one database (`var.db_name`) and one user (`var.db_user`).
        *   **Password Management**: The database user password MUST be sourced from Google Secret Manager. Provide a commented-out `data "google_secret_manager_secret_version"` block example in the module demonstrating how to fetch it, with clear instructions for the user to create and populate the secret.
        *   Firewall Rules (defined in VPC module or by passing network tags/SAs to it): Allow TCP traffic to the database's private IP (and port 5432) *only* from designated sources, such as GKE node pool network tags/service accounts and the Bastion host's network tag/service account. Deny all other access.
    *   **Outputs**: Instance connection name, private IP address, database name, user name.

**General Output Requirements:**

*   Generate all necessary Terraform files (`.tf`, example `.tfvars` for `dev` and `production`) for the specified directory structure.
*   Code must be well-formatted (e.g., `terraform fmt`), fully commented (especially for complex logic, security choices, or non-obvious configurations), and use idiomatic HCL.
*   All input variables in modules and environment configurations must have types, detailed descriptions, and sensible defaults or clear indication if a value is mandatory. Implement validation rules for critical inputs.
*   Use the consistent resource naming convention: `gcp_project_id_prefix-${var.environment}-resource_type-specific_name` (allow `gcp_project_id_prefix` to be a variable).
*   Implement comprehensive tagging/labeling for all provisioned resources (e.g., `environment = var.environment`, `application = var.application_name`, `owner = var.team_contact`, `cost_center = var.cost_center`). Make these tags configurable.
*   Provide a basic `README.md` structure for the root of the project outlining:
    *   Brief project overview.
    *   Prerequisites (e.g., gcloud CLI, Terraform, GCP project setup, enabling APIs).
    *   Instructions on how to configure `backend.tf` and `terraform.tfvars` for each environment.
    *   Basic Terraform commands for deployment (`init`, `plan`, `apply`).
    *   A brief description of each module's purpose and key configurable variables.

Your goal is to provide a robust, secure, maintainable, and readily adaptable Terraform foundation that a user can confidently use to bootstrap their `dev` and `production` GCP environments. The solution should be as close to "clone and run" (after configuring variables and secrets) as possible.

**Post-Generation Consideration:** Once the core Terraform codebase is generated, consider implementing automated testing using tools like Terratest to validate module functionality and integration.















Project Naming Convention:
We will use the naming convention: var.project_id_prefix-${var.environment}-resource_type-specific_name.
var.project_id_prefix: A short identifier for your organization or project (e.g., "acme").
var.environment: The deployment environment (e.g., "dev", "prod").
resource_type: A short code for the GCP resource type (e.g., "vpc", "gke", "sql").
specific_name: A descriptive name for the specific instance of the resource (e.g., "main", "primary", "app-backend").
Tagging Strategy:
All resources will be tagged with a standard set of labels, configurable per environment:
environment: (e.g., "dev", "production")
application-name: (e.g., "my-app", "shared-services")
owner-contact: (e.g., "team-alpha@example.com")
cost-center: (e.g., "engineering-123")
managed-by: "terraform"
Let's begin generating the file structure and content.

result :

├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── backend.tf
│   │   └── terraform.tfvars
│   └── production/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── backend.tf
│       └── terraform.tfvars
├── modules/
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   ├── bastion/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   ├── gke/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   ├── alb/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   └── database/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── versions.tf
├── versions.tf
└── README.md

############################################################################################

terraform {
  required_version = "~> 1.7.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.20.0" # Specify a recent, stable version
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.20.0" # Match google provider version if possible
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5.0"
    }
  }
}

######################################################################################################################

# GCP Foundational Infrastructure with Terraform

This Terraform project provisions a common set of foundational infrastructure services on Google Cloud Platform (GCP) for multiple environments (`dev`, `production`). It emphasizes modularity, security, and production best practices.

## Table of Contents

1.  [Project Overview](#project-overview)
2.  [Prerequisites](#prerequisites)
3.  [Directory Structure](#directory-structure)
4.  [Environment Configuration](#environment-configuration)
    *   [Backend Configuration (`backend.tf`)](#backend-configuration-backendtf)
    *   [Variable Configuration (`terraform.tfvars`)](#variable-configuration-terraformtfvars)
5.  [Deployment](#deployment)
6.  [Modules Overview](#modules-overview)
    *   [VPC Module (`modules/vpc`)](#vpc-module-modulesvpc)
    *   [Bastion Module (`modules/bastion`)](#bastion-module-modulesbastion)
    *   [GKE Module (`modules/gke`)](#gke-module-modulesgke)
    *   [ALB Module (`modules/alb`)](#alb-module-modulesalb)
    *   [Database Module (`modules/database`)](#database-module-modulesdatabase)
7.  [Security Considerations](#security-considerations)
    *   [IAM and Service Accounts](#iam-and-service-accounts)
    *   [Firewall Rules](#firewall-rules)
    *   [Secret Management](#secret-management)
8.  [Cost Management](#cost-management)
9.  [Contributing](#contributing)

## 1. Project Overview

This project aims to provide a robust, secure, and maintainable Terraform foundation for bootstrapping GCP environments. It includes modules for:

*   Virtual Private Cloud (VPC) networking
*   Bastion Host for secure access
*   Google Kubernetes Engine (GKE) cluster
*   Global HTTP(S) Load Balancer (ALB)
*   Cloud SQL for PostgreSQL database

## 2. Prerequisites

Before you begin, ensure you have the following:

*   **Google Cloud SDK (gcloud CLI)**: Installed and authenticated.
    *   `gcloud auth application-default login`
    *   `gcloud config set project YOUR_GCP_PROJECT_ID`
*   **Terraform**: Version `~> 1.7.0` installed.
*   **GCP Project**:
    *   A GCP project created and billing enabled.
    *   The following APIs must be enabled in your GCP project (Terraform will attempt to enable them, but it's good practice to ensure they are enabled beforehand):
        *   `compute.googleapis.com` (Compute Engine API)
        *   `container.googleapis.com` (Kubernetes Engine API)
        *   `sqladmin.googleapis.com` (Cloud SQL Admin API)
        *   `servicenetworking.googleapis.com` (Service Networking API - for Cloud SQL private IP)
        *   `secretmanager.googleapis.com` (Secret Manager API)
        *   `iam.googleapis.com` (Identity and Access Management (IAM) API)
        *   `cloudresourcemanager.googleapis.com` (Cloud Resource Manager API)
        *   `artifactregistry.googleapis.com` (Artifact Registry API - if GKE nodes pull from GAR)
        *   `logging.googleapis.com` (Cloud Logging API)
        *   `monitoring.googleapis.com` (Cloud Monitoring API)
*   **GCS Bucket for Terraform State**: A Google Cloud Storage bucket to store Terraform remote state. This bucket must be created manually *before* running `terraform init`. It should have versioning enabled.
    *   Example: `gsutil mb -p YOUR_GCP_PROJECT_ID -l YOUR_REGION gs://your-unique-tfstate-bucket-name`
    *   `gsutil versioning set on gs://your-unique-tfstate-bucket-name`

## 3. Directory Structure
├── environments/ # Environment-specific configurations
│ ├── dev/
│ └── production/
├── modules/ # Reusable infrastructure modules
│ ├── vpc/
│ ├── bastion/
│ ├── gke/
│ ├── alb/
│ └── database/
├── versions.tf # Provider and Terraform version constraints
└── README.md # This file


## 4. Environment Configuration

Each environment (`dev`, `production`) has its own subdirectory under `environments/`.

### Backend Configuration (`backend.tf`)

Navigate to the specific environment directory (e.g., `cd environments/dev`).
Edit the `backend.tf` file:

```hcl
# environments/dev/backend.tf (Example)
terraform {
  backend "gcs" {
    bucket = "your-gcp-project-id-tfstate" # REPLACE with your GCS bucket name
    prefix = "terraform/state/dev"         # Unique prefix for this environment
  }
}


Replace your-gcp-project-id-tfstate with the name of the GCS bucket you created for Terraform state.
The prefix should be unique per environment (e.g., terraform/state/dev, terraform/state/prod).

Variable Configuration (terraform.tfvars)
In each environment directory, create or modify the terraform.tfvars file to provide values for the environment-specific variables.
Example: environments/dev/terraform.tfvars

# GCP Project and Region
gcp_project_id      = "your-actual-gcp-project-id" // REPLACE
gcp_region          = "us-central1"
project_id_prefix   = "mycompany" // Used for resource naming

# Common Tags
common_tags = {
  environment      = "dev"
  application-name = "shared-infra"
  owner-contact    = "dev-team@example.com"
  cost-center      = "dev-cc-123"
}

# VPC Configuration
vpc_name                     = "main"
vpc_subnet_bastion_cidr      = "10.10.1.0/24"
vpc_subnet_gke_cidr          = "10.10.2.0/24"
vpc_subnet_gke_pods_cidr     = "10.20.0.0/16" // Secondary range for GKE Pods
vpc_subnet_gke_services_cidr = "10.30.0.0/20" // Secondary range for GKE Services
vpc_subnet_db_cidr           = "10.10.3.0/24"
bastion_ssh_source_cidrs     = ["YOUR_HOME_OR_OFFICE_IP/32"] // REPLACE

# Bastion Configuration
bastion_machine_type = "e2-micro"

# GKE Configuration
gke_cluster_name_suffix    = "primary"
gke_release_channel        = "REGULAR"
gke_master_authorized_cidrs = {
  "management_network" = "YOUR_MGMT_CIDR/24" // REPLACE if applicable
  # Bastion public IP will be added automatically by the root module
}
gke_node_pools = {
  default-pool = {
    machine_type    = "e2-medium"
    min_count       = 1
    max_count       = 3
    initial_count   = 1
    disk_size_gb    = 50
    disk_type       = "pd-standard"
    image_type      = "COS_CONTAINERD"
    preemptible     = false
    spot            = false
    node_locations  = null # Will use regional cluster's node locations
  }
}
# gke_database_encryption_key = "projects/YOUR_PROJECT/locations/YOUR_REGION/keyRings/YOUR_KEYRING/cryptoKeys/YOUR_KEY" # Optional CMEK

# ALB Configuration
alb_domain_name = "dev.your-domain.com" // REPLACE
# alb_cloud_armor_policy_name = "your-armor-policy" // Optional

# Database (Cloud SQL PostgreSQL) Configuration
db_instance_name_suffix = "main-pg"
db_tier                 = "db-f1-micro" # Smallest tier for dev
db_disk_size_gb         = 20
db_name                 = "appdb_dev"
db_user                 = "appuser_dev"
db_user_password_secret_id = "projects/YOUR_GCP_PROJECT_ID/secrets/dev-db-password/versions/latest" // REPLACE: Secret Manager path

# ... other variables as needed

Replace placeholder values (like YOUR_GCP_PROJECT_ID, your-domain.com, IP CIDRs, secret paths) with your actual values.
Create the referenced Secret Manager secret for the database password before applying.


5. Deployment
Navigate to Environment Directory:
cd environments/dev  # or environments/production

Initialize Terraform:
This command downloads the necessary providers and configures the backend.
terraform init

Review Plan:
This command shows you what resources Terraform will create, modify, or destroy.
terraform plan -out=tfplan

Apply Configuration:
This command applies the changes and provisions the infrastructure.
terraform apply tfplan

To destroy the infrastructure (use with caution):
terraform destroy



6. Modules Overview
VPC Module (modules/vpc)
Purpose: Provisions a custom-mode Virtual Private Cloud (VPC) network with private and public subnets, firewall rules, and a Cloud NAT gateway.
Key Variables: project_id, network_name, subnets (list of subnet configurations), firewall_rules (list of custom firewall rules), enable_flow_logs.
Outputs: VPC ID, subnet IDs, network tags.
Bastion Module (modules/bastion)
Purpose: Deploys a small GCE instance to serve as a bastion host for secure SSH access to private resources.
Key Variables: project_id, zone, machine_type, network_name, subnet_name, ssh_source_cidrs (passed to VPC module for firewall rule).
Outputs: Bastion instance name, public IP, private IP.
GKE Module (modules/gke)
Purpose: Provisions a regional, private Google Kubernetes Engine (GKE) cluster with configurable node pools, Workload Identity, and network policies.
Key Variables: project_id, region, cluster_name, network_name, subnetwork_name, pods_ipv4_cidr_block, services_ipv4_cidr_block, master_authorized_networks_config, node_pools (map of node pool configurations), database_encryption_key (for CMEK).
Outputs: Cluster name, endpoint, CA certificate, node pool service account.
ALB Module (modules/alb)
Purpose: Sets up a global HTTP(S) Load Balancer (ALB) to route external traffic to GKE services, including Google-managed SSL certificates.
Key Variables: project_id, load_balancer_name, domain_name, backend_negs (list of Network Endpoint Group details for GKE services), cloud_armor_policy_name.
Outputs: LB IP address, managed SSL certificate name.
Note on GKE NEGs: This module expects you to provide details of Network Endpoint Groups (NEGs) that are typically created and managed by the GKE NEG controller when you annotate your Kubernetes Services.
Example GKE Service annotation for NEG creation:

apiVersion: v1
kind: Service
metadata:
  name: my-app-service
  namespace: default
  annotations:
    cloud.google.com/neg: '{"exposed_ports": {"8080":{"name": "my-app-service-8080-neg"}}}'
spec:
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
    name: http
  selector:
    app: my-app
  type: ClusterIP # or LoadBalancer if you need an L4 LB too, but for ALB, ClusterIP is fine for NEGs

  You would then pass [{ name = "my-app-service-8080-neg", zone = "us-central1-a" }] (adjust zone) to the backend_negs variable of the ALB module.

  Database Module (modules/database)
Purpose: Provisions a Cloud SQL for PostgreSQL instance with high availability, private IP, and automated backups.
Key Variables: project_id, region, instance_name, database_version, tier, disk_size_gb, db_name, db_user_name, db_user_password_secret_id (Secret Manager path), authorized_network_sources (for firewall rules).
Outputs: Instance connection name, private IP address.
7. Security Considerations
IAM and Service Accounts
Principle of Least Privilege: Each module creates dedicated service accounts for its resources (e.g., GKE nodes, Bastion instance) with minimal necessary pre-defined roles.
Workload Identity: Enabled for GKE to allow Kubernetes service accounts to impersonate GCP service accounts securely.
Firewall Rules
Default Deny: The VPC is configured with a default-deny ingress policy.
Specific Allows: Firewall rules are explicitly defined to allow necessary traffic (e.g., SSH to bastion from specified IPs, internal VPC traffic, GKE control plane to nodes, database access from GKE/bastion).
Regularly review and audit firewall rules.
Secret Management
Google Secret Manager: Used for storing sensitive data like database passwords.
Never hardcode secrets in Terraform configuration files. Use data sources to fetch them at apply time.
Instructions for Database Password:
Create a secret in Google Secret Manager:

gcloud secrets create dev-db-password --replication-policy="automatic" --project="YOUR_GCP_PROJECT_ID"

Add a version to the secret with the desired password:
echo -n "YourSuperSecureP@ssw0rd" | gcloud secrets versions add dev-db-password --data-file=- --project="YOUR_GCP_PROJECT_ID"
Update terraform.tfvars with the correct db_user_password_secret_id.


8. Cost Management
Resource Sizing: Variables are provided to configure instance types, disk sizes, and cluster sizes to match workload requirements and budget. dev environment defaults are generally smaller.
Tagging: All resources are tagged with environment, application-name, owner-contact, and cost-center labels for cost tracking and allocation. Ensure these are set correctly in terraform.tfvars.
Review GCP Billing Reports: Regularly monitor your GCP billing reports to understand cost drivers.
Consider Preemptible/Spot VMs: For non-critical workloads or certain GKE node pools, consider using preemptible or Spot VMs to reduce costs (configurable in the GKE module).
9. Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.


---
**`environments/dev/backend.tf`**
---
```hcl
# environments/dev/backend.tf
terraform {
  backend "gcs" {
    bucket = "your-gcp-project-id-tfstate-bucket" # <<< REPLACE with your actual GCS bucket name
    prefix = "terraform/state/dev"
  }
}

environments/dev/variables.tf
    