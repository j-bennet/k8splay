cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: nginx-gateway
  namespace: nginx-gateway
spec:
  gatewayClassName: nginx # Use the gateway class that matches your controller
  listeners:
  - name: https
    port: 443
    protocol: HTTPS
    hostname: gateway.web.k8s.local
    tls:
      mode: Terminate
      certificateRefs:
      - kind: Secret
        name: web-tls-secret
        namespace: web-app
    allowedRoutes:
      namespaces:
        from: All
  - name: http
    port: 80
    protocol: HTTP
    hostname: gateway.web.k8s.local
    allowedRoutes:
      namespaces:
        from: All
EOF

# Verify the Gateway resource
kubectl get gateway -n nginx-gateway