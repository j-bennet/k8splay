cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-gateway-to-web-app-secrets
  namespace: web-app # This ReferenceGrant must be in the namespace of the Secret
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: Gateway
    namespace: nginx-gateway # This specifies which namespace is allowed to reference
  to:
  - group: "" # Core API group for Secrets
    kind: Secret
    name: web-tls-secret # Optionally, restrict to a specific secret name (or omit name for all secrets)
EOF