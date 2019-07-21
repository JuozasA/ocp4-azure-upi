locals {
  // The name of the masters' ipconfiguration is hardcoded to "pipconfig". It needs to match cluster-api
  // https://github.com/openshift/cluster-api-provider-azure/blob/master/pkg/cloud/azure/services/networkinterfaces/networkinterfaces.go#L131
  ip_configuration_name = "pipConfig"
  cluster_nr = "${split("-", "${var.cluster_id}")[length(split("-", "${var.cluster_id}")) - 1]}"
}

resource "azurerm_network_interface" "worker" {
  name                = "${var.cluster_id}-worker${var.index}-nic"
  location            = "${var.azure_region}"
  resource_group_name = "${var.cluster_id}-rg"

  ip_configuration {
    subnet_id                     = "${data.azurerm_subscription.current.id}/resourceGroups/${var.cluster_id}-rg/providers/Microsoft.Network/virtualNetworks/${var.cluster_id}-vnet/subnets/${var.cluster_id}-worker-subnet"
    name                          = "${local.ip_configuration_name}"
    private_ip_address_allocation = "Dynamic"
  }
}

provider "azurerm" {
  subscription_id = "${var.azure_subscription_id}"
  client_id       = "${var.azure_client_id}"
  client_secret   = "${var.azure_client_secret}"
  tenant_id       = "${var.azure_tenant_id}"
}

data "azurerm_subscription" "current" {
}

resource "azurerm_virtual_machine" "worker" {
  name                  = "${var.cluster_id}-worker-${var.index}"
  location              = "${var.azure_region}"
  resource_group_name   = "${var.cluster_id}-rg"
  network_interface_ids = ["${azurerm_virtual_machine.worker.id}"]
  vm_size               = "${var.azure_worker_vm_type}"
  zones                 = ["${var.availability_zone}"]
  tags                  = { "openshift": "compute" }

  identity {
    type         = "UserAssigned"
    identity_ids = ["${data.azurerm_subscription.current.id}/resourcegroups/${var.cluster_id}-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/identity${local.cluster_nr}"]
  }

  storage_os_disk {
    name              = "${var.cluster_id}-worker-${var.index}_OSDisk" # os disk name needs to match cluster-api convention
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
    disk_size_gb      = "${var.azure_worker_root_volume_size}"
  }

  storage_image_reference {
    id = "${data.azurerm_subscription.current.id}${var.azure_image_id}"
  }

  //we don't provide a ssh key, because it is set with ignition. 
  //it is required to provide at least 1 auth method to deploy a linux vm
  os_profile {
    computer_name  = "${var.cluster_id}-worker-${var.index}"
    admin_username = "core"
    # The password is normally applied by WALA (the Azure agent), but this
    # isn't installed in RHCOS. As a result, this password is never set. It is
    # included here because it is required by the Azure ARM API.
    admin_password = "NotActuallyApplied!"
    custom_data    = "${data.ignition_config.redirect.rendered}"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  boot_diagnostics {
    enabled     = true
    storage_uri = "https://bootdiag${local.cluster_nr}.blob.core.windows.net/"
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "worker" {
  network_interface_id    = "${azurerm_virtual_machine.worker.id}"
  backend_address_pool_id = "${data.azurerm_subscription.current.id}/resourceGroups/${var.cluster_id}-rg/providers/Microsoft.Network/loadBalancers/${var.cluster_id}-public-lb/backendAddressPools/${var.cluster_id}-public-lb-routers"
  ip_configuration_name   = "${local.ip_configuration_name}" #must be the same as nic's ip configuration name.
}

data "azurerm_storage_account" "ignitions" {
  name                     = "ignition${local.cluster_nr}"
  resource_group_name      = "${var.cluster_id}-rg"
}

data "azurerm_storage_account_sas" "ignitions" {
  connection_string = "${data.azurerm_storage_account.ignitions.primary_connection_string}"
  https_only        = true

  resource_types {
    service   = false
    container = false
    object    = true
  }

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }

  start  = timestamp()

  expiry = timeadd(timestamp(), "24h")

  permissions {
    read    = true
    list    = true
    create  = false
    add     = false
    delete  = false
    process = false
    write   = false
    update  = false
  }
}

data "ignition_config" "redirect" {
  replace {
    source = "https://${data.azurerm_storage_account.ignitions.name}.blob.core.windows.net/ignition/worker.ign${data.azurerm_storage_account_sas.ignitions.sas}"
  }
}

