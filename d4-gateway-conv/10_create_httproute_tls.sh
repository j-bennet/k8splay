#!/usr/bin/env bash

set -ex

cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: web-route-https
  namespace: web-app
spec:
  parentRefs:
  - name: nginx-gateway
    kind: Gateway
    namespace: nginx-gateway
    sectionName: https
  hostnames:
  - gateway.web.k8s.local
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: web-service
      port: 80
EOF

# Verify the HTTPRoute resources
kubectl get httproute -n web-app
