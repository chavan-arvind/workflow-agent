# Define variables
variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "gemini_api_key" {
  description = "API key for Gemini"
  type        = string
}

# Define the Cloud Storage bucket
resource "google_storage_bucket" "cloud_function_source_bucket" {
  name     = "cloud-function-alert-${var.project_id}"
  location = var.region
  project  = var.project_id

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}

# Enable Cloud Run API
resource "google_project_service" "run_api" {
  service = "run.googleapis.com"
  project = var.project_id

  disable_on_destroy = false
}

# Cloud Run service
resource "google_cloud_run_service" "workflow_agent" {
  name     = "workflow-agent"
  location = var.region
  project  = var.project_id

  template {
    spec {
      containers {
        image = "gcr.io/${var.project_id}/workflow-agent"
        env {
          name  = "BUCKET_NAME"
          value = google_storage_bucket.cloud_function_source_bucket.name
        }
        env {
          name  = "GEMINI_API_KEY"
          value = var.gemini_api_key
        }
        ports {
          container_port = 8080
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [
    google_project_service.run_api
  ]
}

# IAM entry for all users to invoke the Cloud Run service
resource "google_cloud_run_service_iam_member" "allUsers" {
  service  = google_cloud_run_service.workflow_agent.name
  location = google_cloud_run_service.workflow_agent.location
  role     = "roles/run.invoker"
  member   = "allUsers"
  project  = var.project_id
}