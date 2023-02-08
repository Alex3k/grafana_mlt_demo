variable "grafana_cloud_api_key" {
  type        = string
  description = "The API key for automating Grafana Cloud"
  nullable    = false
}

variable "gcp_project_id" {
  type        = string
  default     = "solutions-engineering-248511"
  description = "The GCP Project ID to use for this deployment"
  nullable    = false
}

variable "gcp_svc_acc_file_path" {
  type        = string
  description = "The path to a GCP service account JSON license file which has Editor permissions to the GCP project"
  nullable    = false
}

variable "owner_name" {
  type        = string
  description = "Your name in lowercase and without spaces for GCP resource identification purposes."
  nullable    = false
}

variable "gcp_region" {
  type        = string
  default     = "us-central1"
  description = "The region to deploy GKE to"
  nullable    = false
}

variable "stack_slug" {
  type     = string
  nullable = false
}

variable "synthetic_monitoring_backend_url" {
  type     = string
  default  = "synthetic-monitoring-grpc.grafana.net:443"
  nullable = false
}

variable "synthetic_monitoring_api_url" {
  type     = string
  default  = "https://synthetic-monitoring-api.grafana.net"
  nullable = false
}


variable "grafana_stack_region_slug" {
  type     = string
  default  = "us"
  nullable = false
}

variable "slack_channel_name" {
  type     = string
  default  = "mlt-demo-workarea"
  nullable = false
}

variable "slack_bot_token" {
  type     = string
  nullable = false
}

variable "service_now_addon_enabled" {
  type     = bool
  nullable = false
  default = false
}

variable "servicenow_url" {
  type     = string
  nullable = false
}

variable "servicenow_username" {
  type     = string
  nullable = false
}

variable "servicenow_password" {
  type     = string
  nullable = false
}
