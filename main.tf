locals {
  project_id              ="workflow-manager-437809"
  region                  = "asia-south1"
  service_account_email   = "terraform-alert-sa@workflow-manager-437809.iam.gserviceaccount.com"
  service_account_roles   = [
    "roles/datastore.owner",
    "roles/logging.configWriter",
    "roles/logging.logWriter",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/storage.admin",
    "roles/cloudkms.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/compute.viewer",
    "roles/iam.serviceAccountKeyAdmin",
    "roles/iam.workloadIdentityPoolAdmin",
    "roles/iam.roleAdmin",
    "roles/pubsub.admin",
    "roles/cloudfunctions.admin",
    "roles/iam.serviceAccountUser",
    "roles/cloudbuild.builds.builder",
    "roles/pubsub.publisher",
    "roles/eventarc.eventReceiver",
    "roles/run.invoker"
  ]
}
 
resource "google_project_iam_member" "runner-sa-roles" {
  for_each = toset(local.service_account_roles)
 
  role    = each.value
  member  = "serviceAccount:${local.service_account_email}"
  project = local.project_id
}
 
# Enable APIs
module "project-services" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "~> 14.4"
 
  project_id                = local.project_id
  activate_apis             = [
    "logging.googleapis.com",
    "iam.googleapis.com",
    "cloudkms.googleapis.com",
    "iamcredentials.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "sts.googleapis.com",
    "monitoring.googleapis.com",
    "cloudfunctions.googleapis.com",
    "pubsub.googleapis.com",
    "eventarc.googleapis.com",
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "storage.googleapis.com"
  ]
  disable_services_on_destroy = false
}
 
# Google storage bucket that contains the code for the cloud function
resource "google_storage_bucket" "cloud_function_source_bucket" {
  name                       = "cloud-function-code-repositories"
  location                   = local.region
  project                    = "workflow-manager-437809"
  force_destroy              = true
  uniform_bucket_level_access = true
}
 
 
# Zip up the source code
data "archive_file" "source" {
  type        = "zip"
  output_path = "${path.module}/src/alert_source.zip"
  source_dir  = "src/"
}
 
# Add source code zip to the Cloud Function's bucket (Cloud_function_bucket) 
resource "google_storage_bucket_object" "zip" {
  source       = data.archive_file.source.output_path
  content_type = "application/zip"
  name         = "functions.zip"
  bucket       = google_storage_bucket.cloud_function_source_bucket.name
  depends_on = [
    google_storage_bucket.cloud_function_source_bucket,
    data.archive_file.source
  ]
}
 
# google auto creates some service accounts for the event triggers with 
# cloud storage, here we get them and give them the pubsub role so that they
# can trigger the cloud function event
data "google_storage_project_service_account" "gcs_account" {
  project = local.project_id
}
 
# Grant pubsub.publisher permission to storage project service account
resource "google_project_iam_binding" "google_storage_project_service_account_is_pubsub_publisher" {
  project = local.project_id
  role    = "roles/pubsub.publisher"
  members = [
    "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}",
  ]
}
 
resource "google_cloudfunctions2_function" "cloneRepoToStorage" {
  name        = "cloud-function-trigger-cloneRepoToStorage"
  location    = local.region
  project     = local.project_id
  description = "Cloud function gen2 trigger using terraform"
 
  build_config {
    runtime     = "nodejs16"
    entry_point = "cloneRepoToStorage"
 
    source {
      storage_source {
        bucket = google_storage_bucket.cloud_function_source_bucket.name
        object = google_storage_bucket_object.zip.name
      }
    }
  }
 
  service_config {
    max_instance_count              = 1
    min_instance_count              = 0
    available_memory                = "256M"
    timeout_seconds                 = 60
    environment_variables           = {
      SERVICE_CONFIG_TEST = "config_test"
    }
    ingress_settings                = "ALLOW_INTERNAL_ONLY"
    all_traffic_on_latest_revision = true
    service_account_email = local.service_account_email
  }
 
 
  depends_on = [
    google_storage_bucket.cloud_function_source_bucket,
    google_storage_bucket_object.zip,
    module.project-services,
    google_project_iam_binding.google_storage_project_service_account_is_pubsub_publisher
  ]
}