############################
# Terraform & Providers
############################
terraform {
  required_version = ">= 1.7"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.117" }
    random  = { source = "hashicorp/random",  version = "~> 3.6" }
    time    = { source = "hashicorp/time",    version = ">= 0.9" }
  }
}

provider "azurerm" {
  features {}
}

############################
# Utilidades
############################
resource "random_string" "kv_suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "random_password" "vm_admin_pass" {
  length  = 16
  special = true
}

data "azurerm_client_config" "current" {}

############################
# 1️⃣ Resource Group
############################
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = var.location
  tags     = var.tags_common
}

############################
# 2️⃣ Key Vault con RBAC habilitado
############################
resource "azurerm_key_vault" "kv" {
  name                       = "${var.prefix}${random_string.kv_suffix.result}"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  sku_name                   = "standard"
  tenant_id                  = data.azurerm_client_config.current.tenant_id

  enable_rbac_authorization  = true           # 🚩 clave para usar RBAC en datos
  purge_protection_enabled   = true
  soft_delete_retention_days = 90
  public_network_access_enabled = true

  tags = merge(var.tags_common, { workload = "secret-store" })
}

############################
# 3️⃣ Rol Secrets Officer para el usuario IaC
############################
resource "azurerm_role_assignment" "iac_user_secrets" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# ⏲️ Espera 180 s para propagación del rol
resource "time_sleep" "wait_role" {
  depends_on      = [azurerm_role_assignment.iac_user_secrets]
  create_duration = "180s"
}

############################
# 4️⃣ Secreto de prueba
############################
resource "azurerm_key_vault_secret" "demo" {
  name         = "demo-secret"
  value        = "TopSecret123!"
  key_vault_id = azurerm_key_vault.kv.id
  tags         = { purpose = "lab" }

  depends_on   = [time_sleep.wait_role]
}

############################
# 5️⃣ Red mínima
############################
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-vnet"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}
resource "azurerm_subnet" "subnet" {
  name                 = "default"
  address_prefixes     = ["10.10.1.0/24"]
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.rg.name
}
resource "azurerm_network_interface" "nic" {
  name                = "${var.prefix}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name                          = "ip"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

############################
# 6️⃣ VM con Managed Identity
############################
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "${var.prefix}-vm"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = "Standard_B1s"

  admin_username  = "azureuser"
  admin_password  = random_password.vm_admin_pass.result
  disable_password_authentication = false

  identity { type = "SystemAssigned" }

  network_interface_ids = [azurerm_network_interface.nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  tags = merge(var.tags_common, { workload = "test-vm" })
}

############################
# 7️⃣ Rol Secrets User para la VM
############################
resource "azurerm_role_assignment" "vm_secrets" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine.vm.identity[0].principal_id
}