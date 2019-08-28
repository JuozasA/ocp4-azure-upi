variable "azure_config_version" {
  description = <<EOF
(internal) This declares the version of the Azure configuration variables.
It has no impact on generated assets but declares the version contract of the configuration.
EOF


  default = "0.1"
}

variable "azure_region" {
  type = "string"
}

variable "azure_bootstrap_vm_type" {
  type = "string"
}

variable "azure_master_vm_type" {
  type = "string"
}

variable "azure_extra_tags" {
  type = map(string)

  description = <<EOF
(optional) Extra Azure tags to be applied to created resources.

Example: `{ "key" = "value" }`
EOF

default = {}
}

variable "azure_master_root_volume_size" {
type        = "string"
}

variable "azure_image_id" {
type        = "string"
}

variable "machine_cidr" {
  type        = "string"
}

variable "cluster_id" {
  type        = "string"
}

variable "master_count" {
  type        = "string"
}

variable "base_domain" {
  type        = "string"
}

variable "azure_subscription_id" {
  type        = "string"
}

variable "azure_client_id" {
  type        = "string"
}

variable "azure_client_secret" {
  type        = "string"
}

variable "azure_tenant_id" {
  type        = "string"
}

