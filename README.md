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
  
  NOTE: Free Trial account is not enough and Pay As You Go is recommended with increased quota for vCPU:<br>
  https://blogs.msdn.microsoft.com/girishp/2015/09/20/increasing-core-quota-limits-in-azure/

### Preparation

1. Prepare Azure Cloud for Openshift installation:<br>
https://github.com/openshift/installer/tree/master/docs/user/azure

You need to follow this Installation section as well:<br>
https://github.com/openshift/installer/blob/d0f7654bc4a0cf73392371962aef68cd9552b5dd/docs/user/azure/install.md

2. Clone this repository

```sh
  $> git clone https://github.com/JuozasA/ocp4-azure-upi.git
  $> cd ocp4-azure-upi
```

3. Initialize Terraform working directories (current and worker):

```sh
$> terraform init
$> cd worker
$> terraform init
$> cd ../
```

4. Download openshift-install binary for 4.2 or latest (4.1 does not have azure option for install-config.yaml file) and get the pull-secret from:<br>
https://cloud.redhat.com/openshift/install/azure/installer-provisioned 

4.1 Download openshift-install 4.1 binary:<br>
https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.1.20/

5. Copy openshift-install for 4.2 and 4.1 binaries (rename 4.2 version to openshift-install-4.2) to `/usr/local/bin` directory<br>
```sh
cp openshift-install /usr/local/bin/

cp openshift-install /usr/local/bin/openshift-install-4.2
```

6. Generate install config files with 4.2 (or latest) installer:<br>
```sh
$> openshift-install-4.2 create install-config --dir=ignition-files
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

6.1. Edit the install-config.yaml file to set the number of compute, or worker, replicas to 0, as shown in the following compute stanza:
```console
compute:
- hyperthreading: Enabled
  name: worker
  platform: {}
  replicas: 0
```

6.2 Make a copy of install-config.yaml file since you'll need the data (e.g. machine CIDR) later.

7. Generate manifests by using 4.1 installer:<br>
```sh
$> openshift-install create manifests --dir=ignition-files
```

7.1. Remove the files that define the control plane machines:<br>
```sh
$> rm -f ignition-files/openshift/99_openshift-cluster-api_master-machines-*
```

7.2. Remove the Kubernetes manifest files that define the worker machines:<br>
```sh
$> rm -f ignition-files/openshift/99_openshift-cluster-api_worker-machineset-*
```

Because you create and manage the worker machines yourself, you do not need to initialize these machines.<br>

8. Obtain the Ignition config files by using 4.1 installer:<br>
```sh
$> openshift-install create ignition-configs --dir=ignition-files
```

9. Extract the infrastructure name from the Ignition config file metadata, run one of the following commands:<br>
```sh
$> jq -r .infraID ignition-files/metadata.json
$> egrep -o 'infraID.*,' ignition-files/metadata.json
```

10. Open terraform.tfvars file and fill in the variables some of them must be the same like in install-config.yaml:<br>
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
azure_base_domain_resource_group_name = "ocp-cluster" <- Resource group for base domain and rhcos vhd blob.
cluster_id = "openshift-lnkh2" <- infraID parameter extracted from metadata.json (step 9.)
base_domain = "example.com"
machine_cidr = "10.0.0.0/16" <- Address range which will be used for VMs
master_count = 3 <- number of masters
```

11. Open `worker/terraform.tfvars` and fill in information there as well.<br>

### Start OCP v4.1 Deployment

You can either run the `upi-ocp-install.sh` script or run the steps manually:

1. Run the installation script:<br>
```sh
$> ./upi-ocp-install.sh
```

> After Control Plane is deployed, script will replace the default Ingress Controller of type `LoadBalancerService` to type `HostNetwork`. This will disable the creation of Public facing Azure Load Balancer and will allow to have a custom Network Security Rules which won't be overwritten by Kubernetes.

> Once this is done, it will continue with Compute nodes deployment.

2. Manual approach:

2.1. Initialize Terraform directory:
```sh
terraform init
```
2.2. Run Terraform Plan and check what resources will be provisioned:
```sh
terraform plan
```
2.3. Once ready, run Terraform apply to provision Control plane resources:
```sh
terraform apply -auto-approve
```
2.4. Once Terraform job is finished, run `openshift-install`. It will check when the bootstraping is finished.
```sh
openshift-install wait-for bootstrap-complete --dir=ignition-files
```

2.5. Once the bootstraping is finished, export `kubeconfig` environment variable and replace the `default` Ingress Controller object with with the one having `endpointPublishingStrategy` of type `HostNetwork`. This will disable the creation of Public facing Azure Load Balancer and will allow to have a custom Network Security Rules which won't be overwritten by Kubernetes. 
```sh
export KUBECONFIG=$(pwd)/ignition-files/auth/kubeconfig
oc delete ingresscontroller default -n openshift-ingress-operator
oc create -f ingresscontroller-default.yaml
```

2.6. Since we dont need bootstrap VM anymore, we can remove it:
```sh
terraform destroy -target=module.bootstrap -auto-approve
```

2.7. Now we can continue with Compute nodes provisioning: 
```sh
cd worker
terraform init 
terraform plan
terraform apply -auto-approve
cd ../
```

2.8. Since we are provisioning Compute nodes manually, we need to approve kubelet CSRs:
```sh
worker_count=`cat worker/terraform.tfvars | grep worker_count | awk '{print $3}'`
while [ $(oc get csr | grep worker | grep Approved | wc -l) != $worker_count ]; do
	oc get csr -o json | jq -r '.items[] | select(.status == {} ) | .metadata.name' | xargs oc adm certificate approve
	sleep 3
done
```

2.9. Check openshift-ingress service type (it should be type: ClusterIP):
```sh
oc get svc -n openshift-ingress
 NAME                      TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)                   AGE
 router-internal-default   *ClusterIP*   172.30.72.53   <none>        80/TCP,443/TCP,1936/TCP   37m
```

2.10. Wait for installation to be completed. Run below command to obtain kubeadmin username/password:
```sh
echo "'kubeadmin' user password: $(cat $(pwd)/ignition-files/auth/kubeadmin-password)" && oc get routes -n openshift-console | awk 'NR==2{print $2}'
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

2. Run `terraform init` and `terraform apply` commands:<br>
```sh
$> cd scaleup
$> terraform init
$> terraform apply
```

> It will ask you to provide the Azure Availability Zone number where you would like to deploy new node and to provide the worker node number (if it is 4th node, then the number is 3 [indexing starts from 0 rather than 1])

3. Approving server certificates for nodes

> To allow Kube APIServer to communicate with the kubelet running on nodes for logs, rsh etc. The administrator needs to approve the CSR generated by each kubelet.

You can approve all `Pending` CSR requests using:

```sh
oc get csr -o json | jq -r '.items[] | select(.status == {} ) | .metadata.name' | xargs oc adm certificate approve
```

### Change Ingress controller type on already provisioned cluster

> Works for IPI and UPI

1. You need to create Load Balancer which will serve routers and add DNS records to forward `*.apps` and `*.apps.<clustername>` to Load Balancer frontend, or use existing Public LB (for control plane) and configure so it forwards the traffic from 443 and 80 to worker nodes.
> You can check the `kubernetes` Load Balancer for configuration example, but Health Check probe will be tcp on ports 80 or 443 instead of "NodePort"/healthz)

2. Run `disable-loadbalancer-service.sh`:
```sh
./disable-loadbalancer-service.sh
```

3. Check if router service is changed to `ClusterIP` and `kubernetes` LB is destroyed.
