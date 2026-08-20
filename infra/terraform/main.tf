locals {
  tags = {
    project     = "flicko"
    environment = var.environment
    managed_by  = "terraform"
  }
}

module "redis" {
  source              = "./modules/redis"
  name                = "flicko-redis-2026"
  resource_group_name = var.resource_group_name
  location            = var.location
  vm_ip               = var.vm_ip
  tags                = local.tags
}

module "cdn" {
  source               = "./modules/cdn"
  name                 = "flicko-cdn-profile"
  resource_group_name  = var.resource_group_name
  location             = var.location
  storage_account_name = var.storage_account_name
  tags                 = local.tags
}

module "container-jobs" {
  source              = "./modules/container-jobs"
  name                = "flicko-jobs-env"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = local.tags
}
