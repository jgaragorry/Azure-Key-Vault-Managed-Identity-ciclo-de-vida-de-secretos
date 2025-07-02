Azure Key Vault + Managed Identity – Ciclo de Vida de Secretos

Objetivo:

Implementar un Key Vault protegido con RBAC y una VM Linux con Managed Identity que acceda a un secreto sin credenciales explícitas.
Al completar, los estudiantes podrán:

Crear recursos Azure con Terraform y buenas prácticas FinOps.

Configurar Key Vault para usar RBAC en lugar de Access Policies.

Asignar roles a usuario IaC y a la VM.

Gestionar tiempo de propagación RBAC con time_sleep.

Validar el flujo de lectura de secretos desde la VM usando MSI.

Índice

Requisitos previos

Estructura del proyecto

Descripción de archivos .tf

Despliegue paso a paso

Verificación y demostración

Consideraciones FinOps

Limpieza

Referencias

Requisitos previos

WSL Ubuntu 24.04 LTS con:

Terraform ≥ 1.7

Azure CLI ≥ 2.60

jq instalado (para parsear JSON)

Permisos de Contributor en la suscripción Azure.

Estructura del proyecto

azure-key-vault-managed-identity-ciclo-de-vida-de-secretos/
├─ main.tf       # Definición RG, VNet, Key Vault, VM, roles, secreto, time_sleep
├─ variables.tf  # Parámetros: región, prefijo, tags FinOps
└─ outputs.tf    # URI del Vault, IP de VM, password admin

Descripción de archivos .tf

main.tf

# 1️⃣ Terraform & Providers
#   - azurerm: crea recursos Azure
#   - random: sufijo aleatorio
#   - time: pausa para RBAC
terraform { ... }

provider "azurerm" { features {} }

data "azurerm_client_config" "current" {}   # recoge tenant_id y object_id

# 2️⃣ Resource Group
resource "azurerm_resource_group" "rg" { ... }

# 3️⃣ Key Vault con RBAC
resource "azurerm_key_vault" "kv" {
  enable_rbac_authorization = true   # 🔑 habilita RBAC en data-plane
  ...
}

# 4️⃣ Role Assignment para usuario IaC
resource "azurerm_role_assignment" "iac_user_secrets" { ... }

# ⏲️ time_sleep.wait_role: espera 60 s para la propagación del rol
resource "time_sleep" "wait_role" { ... }

# 5️⃣ Secreto de prueba (depende de time_sleep)
resource "azurerm_key_vault_secret" "demo" { ... }

# 6️⃣ VNet, Subnet, NIC
resource "azurerm_virtual_network" "vnet" { ... }
resource "azurerm_subnet" "subnet" { ... }
resource "azurerm_network_interface" "nic" { ... }

# 7️⃣ VM Linux con Managed Identity
resource "azurerm_linux_virtual_machine" "vm" { ... identity { type = "SystemAssigned" } }

# 8️⃣ Role Assignment Secrets User para la VM
resource "azurerm_role_assignment" "vm_secrets" { ... }

variables.tf

variable "location" {
  default = "eastus2"
}
variable "prefix" { default = "kvmi" }
variable "tags_common" { type = map(string) default = {
  environment = "lab"
  owner       = "tu.email@example.com"
  project     = "kv-managed-identity-lab"
  cost_center = "demo"
  delete_after = "2025-07-01T23:59:00Z"
} }

outputs.tf

output "key_vault_uri" {
  value       = azurerm_key_vault.kv.vault_uri
  description = "URI del Key Vault"
}
output "vm_private_ip" {
  value       = azurerm_network_interface.nic.private_ip_address
  description = "IP privada de la VM"
}
output "vm_admin_password" {
  value       = random_password.vm_admin_pass.result
  sensitive   = true
  description = "Contraseña admin de la VM"
}

Despliegue paso a paso

Login y suscripción

az login --use-device-code
az account show --query id -o tsv

Inicializa Terraform

terraform init -upgrade

Aplica

terraform apply -auto-approve

Key Vault tarda ≈ 3 min.

Pausa RBAC 60 s.

Secreto y VM ≈ 2 min.

Verificación y demostración

Extraer outputs

VAULT_URI=$(terraform output -raw key_vault_uri)
VM_IP=$(terraform output -raw vm_private_ip)
VM_PASS=$(terraform output -raw vm_admin_password)

Mostrar secreto desde CLI

VAULT_NAME=${VAULT_URI#https://}
VAULT_NAME=${VAULT_NAME%.vault.azure.net}
az keyvault secret show --vault-name $VAULT_NAME --name demo-secret -o table

SSH a la VM

ssh azureuser@$VM_IP
# contraseña: $VM_PASS

Obtener token MSI y leer secreto

TOKEN=$(curl -s -H Metadata:true \
  'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2019-08-15&resource=https://vault.azure.net' \
  | jq -r .access_token)
curl -s -H "Authorization: Bearer $TOKEN" \
  "$VAULT_URI/secrets/demo-secret?api-version=7.3" | jq -r .value
# → TopSecret123!

Consideraciones FinOps

Key Vault Standard: ~ $0.04 USD/día.

VM B1s (4 h demo): ~ $0.03 USD.

Total lab completo ≤ $0.07 USD.

Limpieza

terraform destroy -auto-approve
az group delete -n ${var.prefix}-rg --yes --no-wait

Referencias

https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault

https://www.finops.org/tagging-best-practices

https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview

📋 El ejercicio demuestra Zero-Trust, RBAC data-plane y etiquetado FinOps en Azure. 🎯

