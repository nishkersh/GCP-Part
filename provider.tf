terraform {
  required_providers {
    google = {
        source = "hashicorp/google"
        version = "6.35.0"
    }
  }
}

provider "google" {
  project = "it-devops-tf"
  region  = "asia-south2"
  
}