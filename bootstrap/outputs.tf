output "ip_address" {
  value = "${azurerm_network_interface.bootstrap.private_ip_address}"
}