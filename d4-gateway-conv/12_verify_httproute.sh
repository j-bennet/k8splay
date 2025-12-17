#!/usr/bin/env bash

set -ex

# Check the Gateway status
kubectl describe gateway nginx-gateway -n web-app

# Check the HTTPRoute status
kubectl describe httproute web-route -n web-app

# Check if the HTTPRoute is properly bound to the Gateway
kubectl get httproute web-route -n web-app -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}'

kubectl get httproute web-route-https -n web-app -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}'
