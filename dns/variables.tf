#variable "cluster_domain" {
#  description = "The domain for the cluster that all DNS records must belong"
#  type        = "string"
#}

variable "internal_lb_ipaddress" {
  description = "External API's LB Ip address"
  type        = "string"
}

variable "private_dns_zone_name" {
  description = "private DNS zone name that should be used for records"
  type        = "string"
}

variable "etcd_count" {
  description = "The number of etcd members."
  type        = "string"
}

variable "etcd_ip_addresses" {
  description = "List of string IPs for machines running etcd members."
  type        = list(string)
  default     = []
}

variable "resource_group_name" {
  type        = "string"
  description = "Resource group for the deployment"
}

#variable "ip_address" {
#  type        = "string"
#  description = "Resource group for the deployment"
#}

variable "private_dns_zone_id" {
  type        = "string"
  description = "This is to create explicit dependency on private zone to exist before VMs are created in the vnet. https://github.com/MicrosoftDocs/azure-docs/issues/13728"
}
