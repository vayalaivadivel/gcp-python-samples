terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }

    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "google" {
  project = "project-d25d1c66-5ac7-43e4-974"
  region  = "asia-south1"
  zone    = "asia-south1-a"
}