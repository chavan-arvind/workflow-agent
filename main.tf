resource "google_cloud_run_service" "workflow_agent" {
  name     = "workflow-agent"
  location = var.region

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

resource "google_cloud_run_service_iam_member" "allUsers" {
  service  = google_cloud_run_service.workflow_agent.name
  location = google_cloud_run_service.workflow_agent.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}