# environments/production/backend.tf
terraform {
  backend "gcs" {
    bucket = "your-gcp-project-id-tfstate-bucket" # <<< REPLACE with your actual GCS bucket name
    prefix = "terraform/state/production"
  }
}