output "function_url" {
  value       = google_cloudfunctions2_function.default.url
  description = "The URL of the deployed Cloud Function"
}

output "bucket_name" {
  value       = google_storage_bucket.function_bucket.name
  description = "The name of the created Cloud Storage bucket"
}