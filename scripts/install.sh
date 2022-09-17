#!/bin/bash

NAMESPACE=$1
DEPLOYMENT_PATH=$2

if ! [ -x "$(command -v helm)" ]; then
    echo 'Helm is not installed. Installing now...' >&2
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
    echo 'Helm is already installed.' >&2
fi

kubectl apply -f $DEPLOYMENT_PATH/namespace.yaml

helm repo add argo https://argoproj.github.io/argo-helm

helm install -n $NAMESPACE argo argo/argo-workflows -f $DEPLOYMENT_PATH/argo-values.yaml --debug