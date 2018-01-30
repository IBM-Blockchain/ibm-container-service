#!/bin/bash

# cp ../kube-configs/wipe_shared.yaml.base ../kube-configs/wipe_shared.yaml

if [ "$(kubectl get pvc | grep couchdb1-pvc | wc -l | awk '{print $1}')" == "0" ] || [ "$(kubectl get pvc | grep couchdb2-pvc | wc -l | awk '{print $1}')" == "0" ]; then
	echo "Error Persistent Volumes does not exist.. Cannot run wipeshared"
	exit 1
else
	kubectl create -f ../kube-configs/wipe_shared_couchdb.yaml	
fi

while [ "$(kubectl get pod -a wipeshared-couchdb | grep wipeshared-couchdb | awk '{print $3}')" != "Completed" ]; do
    echo "Waiting for the shared folder to be erased"
    sleep 1;
done

kubectl delete -f ../kube-configs/wipe_shared_couchdb.yaml
