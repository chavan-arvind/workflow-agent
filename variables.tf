variable "project_id" {
  description = "The ID of the project in which to provision resources."
  type        = string
}

variable "region" {
  description = "The region in which to provision resources."
  type        = string
  default     = "asia-south1"
}

variable "gemini_api_key" {
  description = "The API key for Gemini."
  type        = string
  sensitive   = true
}