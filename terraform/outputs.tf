output "cloud_run_service_url" {
  description = "URL of the deployed n8n Cloud Run service."
  value       = google_cloud_run_v2_service.n8n.uri
}

output "cloud_sql_instance_name" {
  description = "Name of the Cloud SQL instance."
  value       = google_sql_database_instance.n8n_db_instance.name
}

output "cloud_sql_connection_name" {
  description = "Connection name for the Cloud SQL instance."
  value       = google_sql_database_instance.n8n_db_instance.connection_name
}

output "service_account_email" {
  description = "Email of the service account used by Cloud Run."
  value       = google_service_account.n8n_sa.email
}

output "region" {
  description = "Region where resources are deployed."
  value       = var.gcp_region
}

output "next_steps" {
  description = "Next steps after deployment."
  value       = <<-EOT
  
  ========================================
  n8n Deployment Successful! 🎉
  ========================================
  
  Your n8n instance is available at:
  ${google_cloud_run_v2_service.n8n.uri}
  
  Next Steps:
  1. Open the URL above in your browser
  2. Create your first admin account
  3. Start building workflows!
  
  Optional - Connect to Google Services:
  1. Enable required APIs (e.g., Google Sheets, Drive)
  2. Configure OAuth consent screen in Google Cloud Console
  3. Create OAuth credentials
  4. Add credentials in n8n
  
  Useful Commands:
  - View logs:    gcloud run services logs read n8n --region=${var.gcp_region} --limit=50
  - Health check: ./scripts/health-check.sh
  - Update:       terraform apply
  - Cleanup:      terraform destroy
  
  See QUICKSTART.md for detailed instructions.
  ========================================
  
  EOT
}

