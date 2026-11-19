provider "azurerm" {
  features {}
}

variable "location" {
  type    = string
  default = "spaincentral"
}

variable "resource_group_name" {
  type = string
}

variable "acr_name" {
  type = string
}

variable "audit_worm_storage_account_name" {
  type = string
}

variable "audit_worm_retention_days" {
  type    = number
  default = 365
}

variable "audit_worm_policy_locked" {
  type    = bool
  default = false
}

variable "audit_rbac_principal_id" {
  type = string
}

resource "azurerm_resource_group" "sdm" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_container_registry" "sdm" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.sdm.name
  location            = azurerm_resource_group.sdm.location
  sku                 = "Standard"
  admin_enabled       = false
}

resource "azurerm_storage_account" "audit_worm" {
  name                            = var.audit_worm_storage_account_name
  resource_group_name             = azurerm_resource_group.sdm.name
  location                        = azurerm_resource_group.sdm.location
  account_tier                    = "Standard"
  account_replication_type        = "ZRS"
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false

  blob_properties {
    versioning_enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Project    = "sdm-zero-pii"
    Purpose    = "audit-evidence-worm"
    Compliance = "ISO27001-ENS"
    ManagedBy  = "terraform"
  }
}

resource "azurerm_storage_container" "audit_worm" {
  name                  = "audit-evidence-worm"
  storage_account_id    = azurerm_storage_account.audit_worm.id
  container_access_type = "private"

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_container_immutability_policy" "audit_worm" {
  storage_container_resource_manager_id = azurerm_storage_container.audit_worm.id
  immutability_period_in_days           = var.audit_worm_retention_days
  locked                                = var.audit_worm_policy_locked
  protected_append_writes_enabled       = false
  protected_append_writes_all_enabled   = false
}

resource "azurerm_role_assignment" "audit_worm_writer" {
  scope                = azurerm_storage_container.audit_worm.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.audit_rbac_principal_id
}

output "acr_login_server" { value = azurerm_container_registry.sdm.login_server }
output "audit_worm_storage_account_name" { value = azurerm_storage_account.audit_worm.name }
output "audit_worm_container_id" { value = azurerm_storage_container.audit_worm.id }
