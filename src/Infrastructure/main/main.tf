resource "azurerm_resource_group" "sedr" {
  name     = var.resource_name_prefix
  location = var.resource_group_location
  tags     = local.common_tags
  lifecycle { ignore_changes = [tags] }
}
