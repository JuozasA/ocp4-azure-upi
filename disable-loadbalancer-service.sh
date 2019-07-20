! /bin/bash

if [ $(oc get ingresscontrollers -n openshift-ingress-operator | awk 'NR>1{print $1}' | wc -l) != 0 ]; then
	for ingress in $(oc get ingresscontrollers -n openshift-ingress-operator | awk 'NR>1{print $1}'); do
		oc delete ingresscontroller $ingress -n openshift-ingress-operator
	done
fi

oc create -f ./ingresscontroller-default.yaml

oc describe ingresscontroller/default -n openshift-ingress-operator

echo "******************************************"

sleep 5

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