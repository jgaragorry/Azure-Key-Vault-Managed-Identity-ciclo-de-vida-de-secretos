############################
# Variables
############################
variable "location" {
  description = "Región Azure"
  default     = "eastus2"
}

variable "prefix" {
  description = "Prefijo recursos"
  default     = "kvmi"
}

variable "tags_common" {
  description = "Etiquetas FinOps"
  type        = map(string)
  default = {
    environment  = "lab"
    owner        = "tu.email@example.com"
    project      = "kv-managed-identity-lab"
    cost_center  = "demo"
    delete_after = "2025-07-01T23:59:00Z"
  }
}