output "environment_id" { value = azurerm_container_app_environment.env.id }
output "job_ids" { value = [
  azurerm_container_app_job.email_batch.id,
  azurerm_container_app_job.analytics_agg.id,
  azurerm_container_app_job.data_cleanup.id,
  azurerm_container_app_job.search_reindex.id
] }
