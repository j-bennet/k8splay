#!/usr/bin/env bash

set -ex

# port forward for minikube
sudo kubectl port-forward svc/ingress-nginx-controller -n ingress-nginx 80:80


# Add an entry to /etc/hosts for local testing (minikube)
echo "127.0.0.1 gateway.web.k8s.local" | sudo tee -a /etc/hosts

# Add an entry to /etc/hosts for local testing
# echo "$(kubectl get ingress web -n web-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}') gateway.web.k8s.local" | sudo tee -a /etc/hosts

# Test HTTP access
curl -k http://gateway.web.k8s.local/
curl -k https://gateway.web.k8s.local/