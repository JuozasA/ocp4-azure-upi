resource "azurerm_subnet" "master_subnet" {
  resource_group_name  = "${var.resource_group_name}"
  address_prefix       = "${var.master_subnet_cidr}"
  virtual_network_name = "${var.vnet_name}"
  name                 = "${var.cluster_id}-master-subnet"
}

resource "azurerm_subnet" "node_subnet" {
  resource_group_name  = "${var.resource_group_name}"
  address_prefix       = "${var.node_subnet_cidr}"
  virtual_network_name = "${var.vnet_name}"
  name                 = "${var.cluster_id}-worker-subnet"
}

