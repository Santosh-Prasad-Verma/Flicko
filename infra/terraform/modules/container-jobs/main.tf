resource "azurerm_log_analytics_workspace" "logs" {
  name                = "${var.name}-logs"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_container_app_environment" "env" {
  name                       = var.name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.logs.id
  tags                       = var.tags
}

resource "azurerm_container_app_job" "email_batch" {
  name                         = "flicko-email-batch"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  container_app_environment_id = azurerm_container_app_environment.env.id
  replica_timeout_in_seconds   = 1800
  tags                         = var.tags

  manual_trigger_config {
    parallelism              = 1
    replica_completion_count = 1
  }

  template {
    container {
      name   = "email-batch"
      image  = "flickoacr2026.azurecr.io/flicko/jobs:latest"
      cpu    = 0.5
      memory = "1Gi"
    }
  }
}

resource "azurerm_container_app_job" "analytics_agg" {
  name                         = "flicko-analytics-agg"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  container_app_environment_id = azurerm_container_app_environment.env.id
  replica_timeout_in_seconds   = 1800
  tags                         = var.tags

  schedule_trigger_config {
    cron_expression          = "0 2 * * *"
    parallelism              = 1
    replica_completion_count = 1
  }

  template {
    container {
      name   = "analytics-agg"
      image  = "flickoacr2026.azurecr.io/flicko/jobs:latest"
      cpu    = 0.5
      memory = "1Gi"
    }
  }
}

resource "azurerm_container_app_job" "data_cleanup" {
  name                         = "flicko-data-cleanup"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  container_app_environment_id = azurerm_container_app_environment.env.id
  replica_timeout_in_seconds   = 1800
  tags                         = var.tags

  schedule_trigger_config {
    cron_expression          = "0 3 1 * *"
    parallelism              = 1
    replica_completion_count = 1
  }

  template {
    container {
      name   = "data-cleanup"
      image  = "flickoacr2026.azurecr.io/flicko/jobs:latest"
      cpu    = 0.5
      memory = "1Gi"
    }
  }
}

resource "azurerm_container_app_job" "search_reindex" {
  name                         = "flicko-search-reindex"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  container_app_environment_id = azurerm_container_app_environment.env.id
  replica_timeout_in_seconds   = 1800
  tags                         = var.tags

  schedule_trigger_config {
    cron_expression          = "0 4 * * 0"
    parallelism              = 1
    replica_completion_count = 1
  }

  template {
    container {
      name   = "search-reindex"
      image  = "flickoacr2026.azurecr.io/flicko/jobs:latest"
      cpu    = 0.5
      memory = "1Gi"
    }
  }
}
