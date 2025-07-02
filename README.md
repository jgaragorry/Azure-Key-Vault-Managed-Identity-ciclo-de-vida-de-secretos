# 🔐 Azure Key Vault + Managed Identity – Ciclo de Vida de Secretos

> **Objetivo:** Implementar un Key Vault protegido con RBAC y una VM Linux con Managed Identity que acceda a un secreto sin credenciales explícitas.

---

## 🧠 Aprenderás a:

- Crear recursos en Azure con Terraform y buenas prácticas FinOps.
- Configurar Key Vault con control de acceso basado en roles (RBAC).
- Asignar permisos tanto a usuario IaC como a la VM.
- Gestionar el tiempo de propagación de RBAC con `time_sleep`.
- Validar la lectura de secretos desde una VM usando Managed Identity (MSI).

---

## 📚 Índice

- [📋 Requisitos previos](#-requisitos-previos)
- [📁 Estructura del proyecto](#-estructura-del-proyecto)
- [📝 Descripción de archivos .tf](#-descripción-de-archivos-tf)
- [🚀 Despliegue paso a paso](#-despliegue-paso-a-paso)
- [🔍 Verificación y demostración](#-verificación-y-demostración)
- [💸 Consideraciones FinOps](#-consideraciones-finops)
- [🧹 Limpieza](#-limpieza)
- [🔗 Referencias](#-referencias)

---

## 📋 Requisitos previos

| Herramienta     | Versión mínima | Sistema               |
|-----------------|----------------|------------------------|
| Terraform       | 1.7+           | WSL Ubuntu 24.04       |
| Azure CLI       | 2.60+          |                       |
| jq              | —              | (para parsear JSON)    |
| Permisos Azure  | Contributor    | Subscripción activa    |

---

## 📁 Estructura del proyecto

```
azure-key-vault-managed-identity-ciclo-de-vida-de-secretos/
├── main.tf         # Infraestructura principal
├── variables.tf    # Variables: región, prefijo, etiquetas FinOps
└── outputs.tf      # URI del Vault, IP de VM, password admin
```

---

## 📝 Descripción de archivos .tf

### `main.tf`

- Terraform y providers (azurerm, random, time)
- Key Vault con `enable_rbac_authorization = true`
- Asignación de roles para usuario y VM
- Recursos de red: VNet, Subnet, NIC
- VM Linux con Managed Identity
- Secreto de prueba
- `time_sleep` para propagación de RBAC

### `variables.tf`

Variables como:

```hcl
location  = "eastus2"
prefix    = "kvmi"
tags_common = {
  environment  = "lab"
  owner        = "tu.email@example.com"
  project      = "kv-managed-identity-lab"
  cost_center  = "demo"
  delete_after = "2025-07-01T23:59:00Z"
}
```

### `outputs.tf`

Exporta:

- URI del Key Vault
- IP privada de la VM
- Contraseña de administrador (sensible)

---

## 🚀 Despliegue paso a paso

```bash
# 1. Inicia sesión y selecciona tu suscripción
az login --use-device-code
az account show --query id -o tsv

# 2. Inicializa Terraform
terraform init -upgrade

# 3. Aplica la configuración
terraform apply -auto-approve
```

📌 Duración aproximada:

- Key Vault: 3 minutos
- time_sleep: 1 minuto
- Secreto y VM: 2 minutos

---

## 🔍 Verificación y demostración

```bash
# Extraer valores
VAULT_URI=$(terraform output -raw key_vault_uri)
VM_IP=$(terraform output -raw vm_private_ip)
VM_PASS=$(terraform output -raw vm_admin_password)

# Mostrar secreto desde CLI
VAULT_NAME=${VAULT_URI#https://}
VAULT_NAME=${VAULT_NAME%.vault.azure.net}
az keyvault secret show --vault-name $VAULT_NAME --name demo-secret -o table

# Acceder a la VM por SSH
ssh azureuser@$VM_IP
# Contraseña: $VM_PASS

# Leer secreto desde la VM usando MSI
TOKEN=$(curl -s -H Metadata:true \
  'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2019-08-15&resource=https://vault.azure.net' \
  | jq -r .access_token)

curl -s -H "Authorization: Bearer $TOKEN" \
  "$VAULT_URI/secrets/demo-secret?api-version=7.3" | jq -r .value
# → TopSecret123!
```

---

## 💸 Consideraciones FinOps

| Recurso     | Costo aproximado |
|-------------|------------------|
| Key Vault   | $0.04 USD/día    |
| VM B1s (4h) | $0.03 USD        |
| **Total**   | ≤ $0.07 USD      |

---

## 🧹 Limpieza

```bash
terraform destroy -auto-approve
az group delete -n kvmi-rg --yes --no-wait
```

---

## 🔗 Referencias

- [🔐 Key Vault (Terraform)](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault)
- [🏷️ Etiquetado FinOps](https://www.finops.org/tagging-best-practices)
- [🔁 Managed Identity Overview](https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview)

---

📋 Este ejercicio demuestra buenas prácticas en **Zero-Trust**, acceso seguro con **RBAC en data-plane**, y cumplimiento de etiquetado **FinOps** en Azure. 🎯
