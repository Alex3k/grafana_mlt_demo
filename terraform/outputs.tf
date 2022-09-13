output "gke_connection_command" {
  value = "gcloud container clusters get-credentials ${var.owner_name}-mltdemo --region ${var.gcp_region} --project ${var.gcp_project_id}"
}

output "grafana_url" {
  value = grafana_cloud_stack.stack.url
}