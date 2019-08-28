resource "azurerm_dns_a_record" "apiint_internal" {
  name                = "api-int"
  zone_name           = "${var.private_dns_zone_name}"
  resource_group_name = "${var.resource_group_name}"
  ttl                 = 300
  records             = ["${var.internal_lb_ipaddress}", "${var.ip_address}"]
}

resource "azurerm_dns_a_record" "api_internal" {
  name                = "api"
  zone_name           = "${var.private_dns_zone_name}"
  resource_group_name = "${var.resource_group_name}"
  ttl                 = 300
  records             = ["${var.internal_lb_ipaddress}"]
}

resource "azurerm_dns_a_record" "router_internal" {
  name                = "*.apps"
  zone_name           = "${var.private_dns_zone_name}"
  resource_group_name = "${var.resource_group_name}"
  ttl                 = 300
  records             = ["${var.internal_lb_ipaddress}"]
}

resource "azurerm_dns_a_record" "etcd_a_nodes" {
  count               = "${var.etcd_count}"
  name                = "etcd-${count.index}"
  zone_name           = "${var.private_dns_zone_name}"
  resource_group_name = "${var.resource_group_name}"
  ttl                 = 60
  records             = ["${var.etcd_ip_addresses[count.index]}"]
}

#provisioner "local-exec" {
#    command = "az dns_srv_record ",
#    interpreter = ["PowerShell"]
#  }

resource "azurerm_dns_srv_record" "etcd_cluster" {
  name                = "_etcd-server-ssl._tcp"
  zone_name           = "${var.private_dns_zone_name}"
  resource_group_name = "${var.resource_group_name}"
  ttl                 = 60

  dynamic "record" {
    for_each = "${azurerm_dns_a_record.etcd_a_nodes.*.name}"
    iterator = name
    content {
      target   = "${name.value}.${var.private_dns_zone_name}"
      priority = 10
      weight   = 10
      port     = 2380
    }
  }
}

