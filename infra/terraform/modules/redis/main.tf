resource "azurerm_redis_cache" "redis" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  capacity            = 0
  family              = "C"
  sku_name            = "Basic"
  enable_non_ssl_port = false
  minimum_tls_version = "1.2"
  redis_version       = "6"

  redis_configuration {
    maxmemory_policy = "volatile-lru"
  }

  tags = var.tags
}

resource "azurerm_redis_firewall_rule" "allow_vm" {
  name                = "allow-vm-ip"
  redis_cache_name    = azurerm_redis_cache.redis.name
  resource_group_name = var.resource_group_name
  start_ip            = var.vm_ip
  end_ip              = var.vm_ip
}
