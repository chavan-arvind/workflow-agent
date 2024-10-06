variable "project_id" {
  description = "The GCP project ID"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project ID must be between 6 and 30 characters, start with a letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "region" {
  description = "The GCP region for resources"
  type        = string
  default     = "asia-south1"
  validation {
    condition     = can(regex("^[a-z]+-[a-z]+\\d+$", var.region))
    error_message = "Region must be a valid GCP region name."
  }
}

variable "service_account_email" {
  description = "The email of the service account to use"
  type        = string
}

variable "gemini_api_key" {
  description = "API key for Gemini"
  type        = string
}

locals {
  project_id = var.project_id
  region     = var.region
  
  service_account_roles = [
    "roles/run.admin",
    "roles/storage.admin",
    "roles/iam.serviceAccountUser",
    "roles/cloudbuild.builds.builder",
  ]
  
  labels = {
    environment = "production"
    project     = "repo-cloner"
  }
}

resource "google_project_iam_member" "runner-sa-roles" {
  for_each = toset(local.service_account_roles)
 
  role    = each.value
  member  = "serviceAccount:${var.service_account_email}"
  project = local.project_id
}
 
# Enable APIs
resource "google_project_service" "enabled_services" {
  for_each = toset([
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "storage.googleapis.com",
  ])
  
  project = local.project_id
  service = each.key

  disable_on_destroy = false
}

# Google storage bucket for the application
resource "google_storage_bucket" "app_bucket" {
  name                        = "app-bucket-${local.project_id}"
  location                    = local.region
  project                     = local.project_id
  force_destroy               = true
  uniform_bucket_level_access = true
  labels                      = local.labels
}

# Cloud Run service
resource "google_cloud_run_service" "workflow_agent" {
  name     = "workflow-agent"
  location = local.region
  project  = local.project_id

  template {
    spec {
      containers {
        image = "gcr.io/${local.project_id}/workflow-agent"
        env {
          name  = "BUCKET_NAME"
          value = google_storage_bucket.app_bucket.name
        }
        env {
          name  = "GEMINI_API_KEY"
          value = var.gemini_api_key
        }
      }
      service_account_name = var.service_account_email
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [google_project_service.enabled_services]
}

# IAM entry for all users to invoke the Cloud Run service
resource "google_cloud_run_service_iam_member" "allUsers" {
  service  = google_cloud_run_service.workflow_agent.name
  location = google_cloud_run_service.workflow_agent.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}