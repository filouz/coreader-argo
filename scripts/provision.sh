#!/bin/bash

HOST=https://localhost:6443

curl -sfL https://get.k3s.io | sh -

ln -s /etc/rancher/k3s/k3s.yaml ~/.kube/config

TOKEN=$(cat /var/lib/rancher/k3s/server/node-token)
curl -sfL https://get.k3s.io | K3S_URL=$HOST K3S_TOKEN=$TOKEN sh -
