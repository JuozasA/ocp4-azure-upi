## OCP 4.1 deployment on Azure Cloud using User provisioned Infrastructure

### Architecture:

When using this method, you can: <br>
  * Specify the number of masters and workers you want to provision<br>
  * Change Network Security Group rules in order to lock down the ingress access to the cluster<br>
  * Change Infrastructure component names<br>
  * Add tags

This Terraform based aproach will split VMs accross 3 Azure Availability Zones and will use 2 Zone Redundant Load Balancers (1 Public facing to serve OCP routers and api and 1 Private to serve api-int)<br>

Please see the topology bellow:
![Openshift Container Platform 4.1 Topology on Azure](./images/diagram.svg)

Deployment can be split into 4 steps:
 * Create Control Plane (masters) and Surrounding Infrastructure (LB,DNS,VNET etc.)
 * Destroy Bootstrap VM
 * Set the default Ingress controller to type HostNetwork
 * Create Compute (worker) nodes

### Prereqs:

This method uses the following tools:<br>
  * terraform >= 0.12<br>
  * openshift-cli<br>
  * git<br>
  * jq (optional)

### Preparation

1. Prepare Azure Cloud for Openshift installation:<br>
https://github.com/openshift/installer/tree/master/docs/user/azure

You need to follow this Installation section as well:<br>
https://github.com/openshift/installer/blob/master/docs/user/azure/install.md#setup-your-red-hat-enterprise-linux-coreos-images

1. Clone this repository

```sh
  $> git clone https://github.com/JuozasA/ocp4-azure-upi.git
  $> cd ocp4-azure-upi
```

2. Initialize Terraform working directories:

```sh
$> terraform init
$> cd worker
$> terraform init
$> cd ../
```

3. Download openshift-install binary and get the pull-secret from:<br>
https://cloud.redhat.com/openshift/install/azure/installer-provisioned 

4. Copy openshift-install binary to ocp4-azure-upi directory<br>

5. Generate install config files:<br>
```sh
$> ./openshift-install create install-config --dir=ignition-files
```

```console
$> ./openshift-install create install-config --dir=ignition-files
? SSH Public Key /home/user_id/.ssh/id_rsa.pub
? Platform azure
? azure subscription id xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
? azure tenant id xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
? azure service principal client id xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
? azure service principal client secret xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
? Region <Azure region>
? Base Domain example.com
? Cluster Name <cluster name. this will be used to create subdomain, e.g. test.example.com>
? Pull Secret [? for help]
```

Edit the install-config.yaml file to set the number of compute, or worker, replicas to 0, as shown in the following compute stanza:
```console
compute:
- hyperthreading: Enabled
  name: worker
  platform: {}
  replicas: 0
```

2. Generate manifests:<br>
```sh
$> ./openshift-install create manifests --dir=ignition-files
```

Remove the files that define the control plane machines:<br>
```sh
$> rm -f ignition-files/openshift/99_openshift-cluster-api_master-machines-*
```

Remove the Kubernetes manifest files that define the worker machines:<br>
```sh
$> rm -f ignition-files/openshift/99_openshift-cluster-api_worker-machineset-*
```

Because you create and manage the worker machines yourself, you do not need to initialize these machines.<br>

3. Obtain the Ignition config files:<br>
```sh
$> ./openshift-install create ignition-configs --dir=ignition-files
```

4. Extract the infrastructure name from the Ignition config file metadata, run one of the following commands:<br>
```sh
$> jq -r .infraID ignition-files/metadata.json
$> egrep -o 'infraID.*,' ignition-files/metadata.json
```

5. Open terraform.tfvars file and fill in the variables:<br>
```console
azure_subscription_id = ""
azure_client_id = ""
azure_client_secret = ""
azure_tenant_id = ""
azure_bootstrap_vm_type = "Standard_D4s_v3" <- Size of the bootstrap VM
azure_master_vm_type = "Standard_D4s_v3" <- Size of the Master VMs
azure_master_root_volume_size = 64 <- Disk size for Master VMs
azure_image_id = "/resourceGroups/rhcos_images/providers/Microsoft.Compute/images/rhcostestimage" <- Location of coreos image
azure_region = "uksouth" <- Azure region (the one you've selected when creating install-config)
azure_base_domain_resource_group_name = "ocp-cluster" <- Resource group of base domain and rhcos vhd blob.
cluster_id = "openshift-lnkh2" <- infraID parameter extracted from metadata.json (step 4.)
cluster_domain = "openshift.example.com" <- cluster comain consists of Cluster name and base domain
base_domain = "example.com"
machine_cidr = "10.0.0.0/16" <- Address range which will be used for VMs
master_count = 3 <- number of masters
source_address_prefix = "X.X.X.X/24,10.0.0.0/16" (list of IP addresses or IP addresses/CIDR which will be allowed to access Openshift)
```

6. Open worker/terraform.tfvars and fill in information there as well.<br>

### Run deployment script

7. Run the installation script:<br>
```sh
$> ./upi-ocp-install.sh
```

### Scale Up

In order to add aditional worker node, use terraform scripts in scaleup directory.

1. Fill in other information in terraform vars:
```console
azure_subscription_id = ""
azure_client_id = ""
azure_client_secret = ""
azure_tenant_id = ""
azure_worker_vm_type = "Standard_D2s_v3"
azure_worker_root_volume_size = 64
azure_image_id = "/resourceGroups/rhcos_images/providers/Microsoft.Compute/images/rhcostestimage"
azure_region = "uksouth"
cluster_id = "openshift-lnkh2"
```

2. Run terraform init and the script:<br>
```sh
$> cd scaleup
$> terraform init
$> terraform apply
```

It will ask you to provide the Azure Availability Zone number where you would like to deploy new node and to provide the worker node number (if it is 4th node, then the number is 3 [indexing starts from 0 rather than 1])

3. Approving server certificates for nodes

To allow Kube APIServer to communicate with the kubelet running on nodes for logs, rsh etc. The administrator needs to approve the CSR generated by each kubelet.

You can approve all `Pending` CSR requests using:

```sh
oc get csr -o json | jq -r '.items[] | select(.status == {} ) | .metadata.name' | xargs oc adm certificate approve
```

