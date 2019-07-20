#! /bin/bash

echo "CONTROL PLANE PROVISIONING STARTED..."
terraform apply -auto-approve

./openshift-install wait-for bootstrap-complete --dir=ignition-files

echo "DESTROYING BOOTSTRAP VM..."
terraform destroy -target=module.bootstrap -auto-approve

export KUBECONFIG=$(pwd)/ignition-files/auth/kubeconfig

if [ $(oc get ingresscontrollers -n openshift-ingress-operator | awk 'NR>1{print $1}' | wc -l) != 0 ]; then
	for ingress in $(oc get ingresscontrollers -n openshift-ingress-operator | awk 'NR>1{print $1}'); do
		oc delete ingresscontroller $ingress -n openshift-ingress-operator
	done
fi

oc create -f ./ingresscontroller-default.yaml

oc describe ingresscontroller/default -n openshift-ingress-operator

echo "******************************************"

sleep 5

echo "WORKERS PROVISIONING STARTED...\n"

cd worker

terraform apply -auto-approve

worker_count=`cat terraform.tfvars | grep worker_count | awk '{print $3}'`

while [ $(oc get csr | grep worker | grep Approved | wc -l) != $worker_count ]; do
	oc get csr -o json | jq -r '.items[] | select(.status == {} ) | .metadata.name' | xargs oc adm certificate approve
	sleep 3
done

cd ../

./openshift-install wait-for install-complete --dir=ignition-files 2> /dev/null

oc get svc -n openshift-ingress

while [ $(oc get pods -n openshift-ingress | awk 'NR==2{print $2}') != "1/1" ]; do
	oc get pods -n openshift-ingress
	sleep 3
done

oc get pods -n openshift-ingress

echo "Checking Openshift Web Console URL:"
sleep 2
echo "curl -kI https://console-openshift-console.apps.$(oc get dns/cluster -o yaml | grep baseDomain | awk '{print $2}')"

echo "\n"

curl -kI https://console-openshift-console.apps.$(oc get dns/cluster -o yaml | grep baseDomain | awk '{print $2}')

./openshift-install wait-for install-complete --dir=ignition-files
