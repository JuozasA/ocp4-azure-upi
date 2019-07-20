variable "vnet_name" {
  type = "string"
}

variable "master_subnet_cidr" {
  type        = "string"
  description = "The subnet for the masters"
}

variable "node_subnet_cidr" {
  type        = "string"
  description = "The subnet for the workers"
}

variable "resource_group_name" {
  type        = "string"
  description = "Resource group for the deployment"
}

variable "cluster_id" {
  type = "string"
}

variable "region" {
  type        = "string"
  description = "The target Azure region for the cluster."
}

variable "dns_label" {
  type        = "string"
  description = "The label used to build the dns name. i.e. <label>.<region>.cloudapp.azure.com"
}

variable "source_address_prefix" {
  type = "string"
}

variable "private_dns_zone_id" {
  type        = "string"
  description = "This is to create explicit dependency on private zone to exist before VMs are created in the vnet. https://github.com/MicrosoftDocs/azure-docs/issues/13728"
}