#!/bin/bash

if [ "${PWD##*/}" == "create" ]; then
    KUBECONFIG_FOLDER=${PWD}/../../kube-configs
elif [ "${PWD##*/}" == "scripts" ]; then
    KUBECONFIG_FOLDER=${PWD}/../kube-configs
else
    echo "Please run the script from 'scripts' or 'scripts/create' folder"
fi

WITH_COUCHDB=false
PAID=false

Parse_Arguments() {
	while [ $# -gt 0 ]; do
		case $1 in
			--with-couchdb)
				echo "Configured to setup network with couchdb"
				WITH_COUCHDB=true
				;;
			--paid)
				echo "Configured to setup a paid storage on ibm-cs"
				PAID=true
				;;
		esac
		shift
	done
}

Parse_Arguments $@

if [ "${PAID}" == "true" ]; then
	OFFERING="paid"
else
	OFFERING="free"
fi

echo "Creating Services for blockchain network"
if [ "${WITH_COUCHDB}" == "true" ]; then
    # Use the yaml file with couchdb
    echo "Running: kubectl create -f ${KUBECONFIG_FOLDER}/blockchain-couchdb-services-${OFFERING}.yaml"
    kubectl create -f ${KUBECONFIG_FOLDER}/blockchain-couchdb-services-${OFFERING}.yaml
else
    echo "Running: kubectl create -f ${KUBECONFIG_FOLDER}/blockchain-services-${OFFERING}.yaml"
    kubectl create -f ${KUBECONFIG_FOLDER}/blockchain-services-${OFFERING}.yaml
fi

echo "Running: kubectl create -f ${KUBECONFIG_FOLDER}/blockchain-prep.yaml"
kubectl create -f ${KUBECONFIG_FOLDER}/blockchain-prep.yaml

PREPSTATUS=$(kubectl get pods -a prep | grep prep | awk '{print $3}')
while [ "${PREPSTATUS}" != "Running" ]; do
    echo "Waiting for Prep pod to start completion. Status = ${PREPSTATUS}"
    if [ "${PREPSTATUS}" == "Error" ]; then
        echo "There is an error in prep pod. Please run 'kubectl logs prep' or 'kubectl describe pod prep'."
        exit 1
    fi
    PREPSTATUS=$(kubectl get pods -a prep | grep prep | awk '{print $3}')
done

sleep 2

echo "Prep: Copying configuration data to shared volume"
test -d "config" && echo Exists || echo Does not exist
kubectl cp config prep:/shared/config

echo "Prep: Removing container"
kubectl delete -f ${KUBECONFIG_FOLDER}/blockchain-prep.yaml

echo "Creating new Deployment"
if [ "${WITH_COUCHDB}" == "true" ]; then
    # Use the yaml file with couchdb
    echo "Running: kubectl create -f ${KUBECONFIG_FOLDER}/blockchain-couchdb.yaml"
    kubectl create -f ${KUBECONFIG_FOLDER}/blockchain-couchdb.yaml
else
    echo "Running: kubectl create -f ${KUBECONFIG_FOLDER}/blockchain.yaml"
    kubectl create -f ${KUBECONFIG_FOLDER}/blockchain.yaml
fi

echo "Checking if all deployments are ready"

NUMPENDING=$(kubectl get deployments | grep blockchain | awk '{print $5}' | grep 0 | wc -l | awk '{print $1}')
while [ "${NUMPENDING}" != "0" ]; do
    echo "Waiting on pending deployments. Deployments pending = ${NUMPENDING}"
    NUMPENDING=$(kubectl get deployments | grep blockchain | awk '{print $5}' | grep 0 | wc -l | awk '{print $1}')
    sleep 1
done

UTILSSTATUS=$(kubectl get pods utils | grep utils | awk '{print $3}')
while [ "${UTILSSTATUS}" != "Completed" ]; do
    echo "Waiting for Utils pod to start completion. Status = ${UTILSSTATUS}"
    if [ "${UTILSSTATUS}" == "Error" ]; then
        echo "There is an error in utils pod. Please run 'kubectl logs utils' or 'kubectl describe pod utils'."
        exit 1
    fi
    UTILSSTATUS=$(kubectl get pods utils | grep utils | awk '{print $3}')
done


UTILSCOUNT=$(kubectl get pods utils | grep "0/3" | grep "Completed" | wc -l | awk '{print $1}')
while [ "${UTILSCOUNT}" != "1" ]; do
    UTILSLEFT=$(kubectl get pods utils | grep utils | awk '{print $2}')
    echo "Waiting for all containers in Utils pod to complete. Left = ${UTILSLEFT}"
    UTILSSTATUS=$(kubectl get pods utils | grep utils | awk '{print $3}')
    if [ "${UTILSSTATUS}" == "Error" ]; then
        echo "There is an error in utils pod. Please run 'kubectl logs utils' or 'kubectl describe pod utils'."
        exit 1
    fi
    sleep 1
    UTILSCOUNT=$(kubectl get pods utils | grep "0/3" | grep "Completed" | wc -l | awk '{print $1}')
done

echo "Waiting for 15 seconds for peers and orderer to settle"
sleep 15
