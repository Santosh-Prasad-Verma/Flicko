output "redis_hostname" {
  value = module.redis.hostname
}

output "redis_primary_connection_string" {
  value     = module.redis.primary_connection_string
  sensitive = true
}

output "cdn_endpoint_hostname" {
  value = module.cdn.cdn_endpoint_hostname
}

output "container_jobs_env_id" {
  value = module.container-jobs.environment_id
}
