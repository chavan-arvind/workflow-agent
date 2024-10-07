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

data "google_project" "project" {
  project_id = var.project_id
}

provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  service_name = "workflow-agent"
  bucket_name  = "cloud-function-alert-${var.project_id}"
}

# Configure the Google Cloud provider
provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable necessary APIs
resource "google_project_service" "cloudfunctions" {
  service = "cloudfunctions.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloudbuild" {
  service = "cloudbuild.googleapis.com"
  disable_on_destroy = false
}

# Create a Cloud Storage bucket for the function source
resource "google_storage_bucket" "function_bucket" {
  name     = "${var.project_id}-function-source"
  location = var.region
  uniform_bucket_level_access = true
}

# Create a zip of the function source
data "archive_file" "function_source" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/function-source.zip"
}

# Upload the function source to the bucket
resource "google_storage_bucket_object" "function_source" {
  name   = "function-source-${data.archive_file.function_source.output_md5}.zip"
  bucket = google_storage_bucket.function_bucket.name
  source = data.archive_file.function_source.output_path
}

# Deploy the Cloud Function
resource "google_cloudfunctions2_function" "default" {
  name        = "my-cloud-function"
  location    = var.region
  description = "My Cloud Function"

  build_config {
    runtime     = "nodejs16"
    entry_point = "handler" # make sure this matches the exported function name in your index.js
    source {
      storage_source {
        bucket = google_storage_bucket.function_bucket.name
        object = google_storage_bucket_object.function_source.name
      }
    }
  }

  service_config {
    max_instance_count = 1
    available_memory   = "256M"
    timeout_seconds    = 60
    environment_variables = {
      BUCKET_NAME    = google_storage_bucket.function_bucket.name
      GEMINI_API_KEY = var.gemini_api_key
    }
  }

  depends_on = [
    google_project_service.cloudfunctions,
    google_project_service.cloudbuild,
  ]
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions2_function_iam_member" "invoker" {
  project        = google_cloudfunctions2_function.default.project
  location       = google_cloudfunctions2_function.default.location
  cloud_function = google_cloudfunctions2_function.default.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}