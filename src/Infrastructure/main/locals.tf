locals {
  common_tags = {
    CreatedBy   = data.azuread_user.current_user.mail_nickname
    CreatedDate = timestamp()
    Application = var.application_friendly_name
  }
}
