resource "azurerm_cdn_profile" "cdn" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard_Microsoft"
  tags                = var.tags
}

resource "azurerm_cdn_endpoint" "endpoint" {
  name                = "flicko-cdn"
  profile_name        = azurerm_cdn_profile.cdn.name
  location            = var.location
  resource_group_name = var.resource_group_name
  is_http_allowed     = false
  is_https_allowed    = true

  origin {
    name      = "flickostorage"
    host_name = "${var.storage_account_name}.blob.core.windows.net"
  }

  delivery_rule {
    name  = "CacheImagesAudio"
    order = 1

    url_path_condition {
      operator     = "BeginsWith"
      match_values = ["/images/", "/audio/"]
    }

    cache_expiration_action {
      behavior = "Override"
      duration = "7.00:00:00"
    }
  }

  delivery_rule {
    name  = "NoCacheAPI"
    order = 2

    url_path_condition {
      operator     = "BeginsWith"
      match_values = ["/api/"]
    }

    cache_expiration_action {
      behavior = "BypassCache"
    }
  }

  tags = var.tags
}

resource "azurerm_cdn_endpoint_custom_domain" "custom_domain" {
  name            = "cdn-flicko-dev"
  cdn_endpoint_id = azurerm_cdn_endpoint.endpoint.id
  host_name       = "cdn.flicko.dev"

  cdn_managed_https {
    certificate_type = "Dedicated"
    protocol_type    = "ServerNameIndication"
    tls_version      = "TLS12"
  }
}
