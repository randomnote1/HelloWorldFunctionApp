locals {
  common_tags = {
    CreatedBy   = data.azuread_user.current_user.mail_nickname
    CreatedDate = timestamp()
    Application = var.application_friendly_name
  }

  resource_name_prefix = "${var.resource_name_prefix}-HWFA-"

  # Calculate the subnets by adding bits to the base network bits. If the base network is a /24, add 4 bits to get to /28.
  subnets = cidrsubnets(
    var.virtual_network_address_space[0],
    4, # Main
    4, # PrivateLink
  )

  private_dns_zone_names = [
    "privatelink.agentsvc.azure-automation.us",
    "privatelink.blob.core.usgovcloudapi.net",
    "privatelink.monitor.azure.us",
    "privatelink.ods.opinsights.azure.us",
    "privatelink.oms.opinsights.azure.us"
  ]

  # Resource names
  resource_group_name                                    = "${local.resource_name_prefix}RG"
  virtual_network_name                                   = "${local.resource_name_prefix}vNet"
  subnet_main                                            = "${local.resource_name_prefix}vNet-Main"
  subnet_privateEndpoints                                = "${local.resource_name_prefix}vNet-PrivateEndpoints"
  log_analytics_workspace_name                           = "${local.resource_name_prefix}LAW"
  application_insights_name                              = "${local.resource_name_prefix}AI"
  azure_monitor_private_link_scope_name                  = "${local.resource_name_prefix}AMPLS"
  azure_monitor_private_link_scope_private_endpoint_name = "${local.resource_name_prefix}PE-AMPLS"
  storage_account_name                                   = "${local.resource_name_prefix}SA"
  app_service_plan_name                                  = "${local.resource_name_prefix}ASP"
  function_app_name                                      = "${local.resource_name_prefix}FA"

  function_app_permissions_for_function_app_storage = [
    "Storage Account Contributor",
    "Storage Blob Data Contributor",
    "Storage Queue Data Contributor",
    "Storage Table Data Contributor"
  ]

  # Define the path to the SEDR HelloWorld function app
  function_app_path_helloworld = "${path.module}/../../FunctionApps/HelloWorld"

  # Define the path to the SEDR HelloWorld ZIP file
  function_app_zip_path_helloworld = "${path.module}/../../../build/HelloWorld.zip"

  # Get the full names of the HelloWorld function app files
  function_app_all_files_helloworld = fileset(local.function_app_path_helloworld, "**")
}
