output "node_subnet_ids" {
  value = "${local.node_subnet_ids}"
}

output "master_subnet_ids" {
  value = "${local.subnet_ids}"
}

output "internal_lb_backend_pool_id" {
  value = "${azurerm_lb_backend_address_pool.internal_lb_controlplane_pool.id}"
}

output "internal_lb_ip_address" {
  value = "${azurerm_lb.internal.private_ip_address}"
}

output "master_nsg_name" {
  value = "${azurerm_network_security_group.master.name}"
}
