resource "azurerm_resource_group" "resource_group" {
  name     = local.resource_group_name
  location = var.resource_group_location
  tags     = local.common_tags
  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_role_assignment" "resource_group_owner" {
  scope                = azurerm_resource_group.resource_group.id
  role_definition_name = "Owner"
  principal_id         = data.azuread_user.current_user.id
}

##################
### Networking ###
##################

resource "azurerm_virtual_network" "virtual_network" {
  name                = local.virtual_network_name
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  address_space       = var.virtual_network_address_space
  tags                = local.common_tags
  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_subnet" "main" {
  name                 = local.subnet_main
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.virtual_network.name
  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.Web"
  ]
  address_prefixes = [local.subnets[0]]
  delegation {
    name = "${local.function_app_name}-to-${local.subnet_main}"
    service_delegation {
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action"
      ]
      name = "Microsoft.Web/serverFarms"
    }
  }
}

resource "azurerm_subnet" "private_endpoints" {
  name                                      = local.subnet_privateEndpoints
  resource_group_name                       = azurerm_resource_group.resource_group.name
  virtual_network_name                      = azurerm_virtual_network.virtual_network.name
  address_prefixes                          = [local.subnets[1]]
  private_endpoint_network_policies_enabled = false
}

resource "azurerm_private_dns_zone" "virtual_network_private_dns_zones" {
  for_each            = toset(local.private_dns_zone_names)
  name                = each.value
  resource_group_name = azurerm_resource_group.resource_group.name
  tags                = local.common_tags
  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_private_dns_zone_virtual_network_link" "private_dns_zones_virtual_network_links" {
  for_each              = azurerm_private_dns_zone.virtual_network_private_dns_zones
  name                  = each.value.name
  private_dns_zone_name = each.value.name
  resource_group_name   = azurerm_resource_group.resource_group.name
  virtual_network_id    = azurerm_virtual_network.virtual_network.id
  tags                  = local.common_tags
  lifecycle { ignore_changes = [tags] }
}

######################
### End Networking ###
######################

##################
### Monitoring ###
##################

resource "azurerm_log_analytics_workspace" "log_analytics" {
  name                            = lower(local.log_analytics_workspace_name)
  resource_group_name             = azurerm_resource_group.resource_group.name
  location                        = azurerm_resource_group.resource_group.location
  allow_resource_only_permissions = true
  local_authentication_disabled   = false
  sku                             = "PerGB2018"
  retention_in_days               = 90
  daily_quota_gb                  = -1
  tags                            = local.common_tags
  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_application_insights" "app_insights" {
  name                                  = local.application_insights_name
  resource_group_name                   = azurerm_resource_group.resource_group.name
  location                              = azurerm_resource_group.resource_group.location
  application_type                      = "web"
  daily_data_cap_in_gb                  = 100
  daily_data_cap_notifications_disabled = false
  retention_in_days                     = 90
  sampling_percentage                   = 100
  tags                                  = local.common_tags
  workspace_id                          = azurerm_log_analytics_workspace.log_analytics.id
  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_monitor_private_link_scope" "azure_monitor_private_link_scope" {
  name                = local.azure_monitor_private_link_scope_name
  resource_group_name = azurerm_resource_group.resource_group.name
  tags                = local.common_tags
  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_monitor_private_link_scoped_service" "private_link_scope_to_app_insights" {
  name                = azurerm_application_insights.app_insights.name
  resource_group_name = azurerm_resource_group.resource_group.name
  scope_name          = azurerm_monitor_private_link_scope.azure_monitor_private_link_scope.name
  linked_resource_id  = azurerm_application_insights.app_insights.id
}

resource "azurerm_private_endpoint" "azure_monitor_private_link_scope" {
  name                = local.azure_monitor_private_link_scope_private_endpoint_name
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.common_tags

  private_service_connection {
    name                           = local.azure_monitor_private_link_scope_private_endpoint_name
    is_manual_connection           = false
    private_connection_resource_id = azurerm_monitor_private_link_scope.azure_monitor_private_link_scope.id
    subresource_names              = ["azuremonitor"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = values(azurerm_private_dns_zone.virtual_network_private_dns_zones)[*].id
  }

  lifecycle { ignore_changes = [tags] }
}

######################
### End Monitoring ###
######################

###############
### Storage ###
###############

resource "azurerm_storage_account" "function_app" {
  name                              = lower(replace(local.storage_account_name, "-", ""))
  resource_group_name               = azurerm_resource_group.resource_group.name
  location                          = azurerm_resource_group.resource_group.location
  account_tier                      = "Standard"
  account_replication_type          = "LRS"
  account_kind                      = "StorageV2"
  allowed_copy_scope                = "PrivateLink"
  enable_https_traffic_only         = true
  infrastructure_encryption_enabled = false
  min_tls_version                   = "TLS1_2"
  public_network_access_enabled     = true

  /*
    The function app cannot connect to the storage share without
    the "shared_access_key_enabled" property enabled.
    https://learn.microsoft.com/en-us/azure/azure-functions/functions-app-settings#website_contentazurefileconnectionstring
  */
  shared_access_key_enabled = true
  tags                      = local.common_tags

  lifecycle { ignore_changes = [tags] }

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    ip_rules       = values(var.admin_ip_address_ranges)
    virtual_network_subnet_ids = [
      azurerm_subnet.main.id
    ]
  }
}

resource "azurerm_storage_share" "hello_world" {
  name                 = lower(local.function_app_name)
  storage_account_name = azurerm_storage_account.function_app.name
  access_tier          = "TransactionOptimized"
  quota                = 5120
}

###################
### End Storage ###
###################

resource "azurerm_service_plan" "service_plan" {
  name                = local.app_service_plan_name
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  os_type             = "Windows"
  sku_name            = "S1"
  worker_count        = 1
  tags                = local.common_tags
  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_windows_function_app" "hello_world" {
  name                          = local.function_app_name
  resource_group_name           = azurerm_resource_group.resource_group.name
  location                      = azurerm_resource_group.resource_group.location
  service_plan_id               = azurerm_service_plan.service_plan.id
  storage_account_name          = azurerm_storage_account.function_app.name
  storage_uses_managed_identity = true
  tags                          = local.common_tags

  app_settings = {
    /*
      These settings are required for configuring the function app to connect to the
      the host storage using an AAD identity.
      https://learn.microsoft.com/azure/azure-functions/functions-reference?tabs=blob#connecting-to-host-storage-with-an-identity
    */
    AzureWebJobsStorage__blobServiceUri  = azurerm_storage_account.function_app.primary_blob_endpoint
    AzureWebJobsStorage__queueServiceUri = azurerm_storage_account.function_app.primary_queue_endpoint
    AzureWebJobsStorage__tableServiceUri = azurerm_storage_account.function_app.primary_table_endpoint

    AzureFunctionsWebHost__hostid            = "Hello World Function App"
    AzureWebJobsDisableHomepage              = "true"
    HubName                                  = "HelloWorldFunctionApp"
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING = azurerm_storage_account.function_app.primary_connection_string
    WEBSITE_CONTENTSHARE                     = azurerm_storage_share.hello_world.name
    WEBSITE_CONTENTOVERVNET                  = "1"
    WEBSITE_LOAD_USER_PROFILE                = "1"
    WEBSITE_RUN_FROM_PACKAGE                 = "1"

    ### Function settings ###
    DebugPreference   = "SilentlyContinue"
    VerbosePreference = "Continue"
  }

  builtin_logging_enabled     = false
  functions_extension_version = "~4"
  https_only                  = true
  virtual_network_subnet_id   = azurerm_subnet.main.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on                              = true
    application_insights_key               = azurerm_application_insights.app_insights.instrumentation_key
    application_insights_connection_string = azurerm_application_insights.app_insights.connection_string
    ftps_state                             = "Disabled"
    http2_enabled                          = true
    minimum_tls_version                    = "1.2"
    scm_use_main_ip_restriction            = false
    use_32_bit_worker                      = false
    vnet_route_all_enabled                 = true

    application_stack {
      powershell_core_version = "7.2"
    }

    cors {
      allowed_origins     = ["https://ms.portal.azure.com"]
      support_credentials = false
    }

    dynamic "ip_restriction" {
      for_each = var.admin_ip_address_ranges
      content {
        name       = ip_restriction.key
        ip_address = "${ip_restriction.value}${length(regexall("/", ip_restriction.value)) > 0 ? "" : "/32"}"
        action     = "Allow"
        priority   = 299
      }
    }

    # Ensure the function app can call itself
    ip_restriction {
      name                      = azurerm_subnet.main.name
      virtual_network_subnet_id = azurerm_subnet.main.id
      action                    = "Allow"
      priority                  = 200

    }

    ip_restriction {
      name        = "AzureCloud"
      service_tag = "AzureCloud"
      action      = "Allow"
      priority    = 300
    }

    dynamic "scm_ip_restriction" {
      for_each = var.admin_ip_address_ranges
      content {
        name       = scm_ip_restriction.key
        ip_address = "${scm_ip_restriction.value}${length(regexall("/", scm_ip_restriction.value)) > 0 ? "" : "/32"}"
        action     = "Allow"
        priority   = 299
      }
    }
  }

  sticky_settings {
    app_setting_names = [
      "AzureFunctionsWebHost__hostid",
      "HubName"
    ]
  }

  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_role_assignment" "helloworld_permissions_to_fa_storage_account" {
  for_each             = toset(local.function_app_permissions_for_function_app_storage)
  scope                = azurerm_storage_account.function_app.id
  role_definition_name = each.key
  principal_id         = azurerm_windows_function_app.hello_world.identity[0].principal_id
}

resource "null_resource" "zip_helloworld" {
  provisioner "local-exec" {
    command     = <<EOT
      $compressArchiveParams = @{
        Path = '${local.function_app_path_helloworld}/*'
        DestinationPath = '${local.function_app_zip_path_helloworld}'
        Force = $true
      }
      Compress-Archive @compressArchiveParams

      az functionapp deployment source config-zip -g ${azurerm_resource_group.resource_group.name} -n ${azurerm_windows_function_app.hello_world.name} --src ${local.function_app_zip_path_helloworld}
    EOT
    interpreter = ["PowerShell", "-Command"]
  }

  triggers = {
    helloworld_checksum = md5(
      join(
        "",
        [
          for f in local.function_app_all_files_helloworld :
          filemd5("${local.function_app_path_helloworld}/${f}")
        ]
      )
    )
  }
}
