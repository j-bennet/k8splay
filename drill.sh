#!/usr/bin/env bash
set -euo pipefail

# CKA drill setup script
# - Creates namespaces and resources for multiple scenarios
# - Optionally "breaks" CNI if a known CNI DaemonSet is found
#
# Requirements:
# - kubectl installed and pointing to a test cluster
# - helm installed (for Helm scenarios)
#
# WARNING: The CNI and etcd-related parts are meant for LAB CLUSTERS ONLY.

info() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*" >&2; }

kubectl_ok() {
  if ! kubectl version --short >/dev/null 2>&1; then
    warn "kubectl not configured or cluster not reachable"
    exit 1
  fi
}

create_ns() {
  local ns="$1"
  if ! kubectl get ns "$ns" >/dev/null 2>&1; then
    kubectl create ns "$ns"
  fi
}

create_configmap_note() {
  local ns="$1"
  local name="$2"
  local note="$3"
  kubectl -n "$ns" delete configmap "$name" >/dev/null 2>&1 || true
  kubectl -n "$ns" create configmap "$name" --from-literal=TASK="$note"
}

scenario_crd() {
  local ns="scenario-crd"
  info "Setting up CRD scenario in namespace $ns"
  create_ns "$ns"

  cat <<EOF | kubectl apply -f -
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: widgets.example.com
spec:
  group: example.com
  names:
    kind: Widget
    listKind: WidgetList
    plural: widgets
    singular: widget
  scope: Namespaced
  versions:
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                size:
                  type: string
                  enum:
                    - small
                    - medium
                    - large
EOF

  # invalid CR to diagnose (fails validation)
  cat <<EOF | kubectl -n "$ns" apply -f - || true
apiVersion: example.com/v1
kind: Widget
metadata:
  name: broken-widget
spec:
  size: gigantic
EOF

  create_configmap_note "$ns" "lab-note" \
"Task: Inspect the CRD widgets.example.com, understand the schema,
fix the broken-widget resource so it passes validation, and create
a valid widget called fixed-widget with size=large."
}

scenario_gateway() {
  local ns="scenario-gateway"
  info "Setting up Gateway scenario in namespace $ns"
  create_ns "$ns"

  # Install Gateway API CRDs if not present
  if ! kubectl get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1; then
    info "Installing Gateway API CRDs"
    kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/latest/download/standard-install.yaml
  fi

  # App + service + legacy Ingress to migrate
  kubectl -n "$ns" apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: nginx
          image: nginx
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
spec:
  rules:
    - host: example.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web
                port:
                  number: 80
EOF

  create_configmap_note "$ns" "lab-note" \
"Task: Migrate this Ingress (web-ingress) to Gateway API. 
Create a GatewayClass, Gateway, and HTTPRoute that routes HTTP traffic
for host example.local to service web port 80."
}

scenario_cni_break() {
  info "Attempting to break CNI (lab clusters only!)"

  # Try Calico first
  if kubectl get ds -A 2>/dev/null | grep -q "calico-node"; then
    local ns
    ns=$(kubectl get ds -A | awk '/calico-node/{print $1; exit}')
    info "Found Calico DaemonSet in namespace $ns, scaling to 0"
    kubectl -n "$ns" scale ds calico-node --replicas=0
    create_configmap_note "kube-system" "lab-cni-note" \
"Task: Nodes should be NotReady due to CNI. Inspect DaemonSets in
the CNI namespace and restore the CNI to bring nodes back to Ready."
    return
  fi

  # Try Flannel
  if kubectl get ds -A 2>/dev/null | grep -q "kube-flannel-ds"; then
    local ns
    ns=$(kubectl get ds -A | awk '/kube-flannel-ds/{print $1; exit}')
    info "Found Flannel DaemonSet in namespace $ns, scaling to 0"
    kubectl -n "$ns" scale ds kube-flannel-ds --replicas=0
    create_configmap_note "kube-system" "lab-cni-note" \
"Task: Nodes should be NotReady due to CNI. Inspect DaemonSets in
the CNI namespace and restore the CNI to bring nodes back to Ready."
    return
  fi

  warn "No known CNI DaemonSet (calico-node or kube-flannel-ds) found; skipping CNI break."
}

scenario_helm() {
  local ns="scenario-helm"
  info "Setting up Helm scenario in namespace $ns"
  create_ns "$ns"

  if ! helm repo list 2>/dev/null | grep -q "bitnami"; then
    helm repo add bitnami https://charts.bitnami.com/bitnami
  fi
  helm repo update

  # Install nginx with odd configuration on purpose
  helm upgrade --install cka-nginx bitnami/nginx \
    --namespace "$ns" \
    --set service.type=ClusterIP \
    --set replicaCount=1

  create_configmap_note "$ns" "lab-note" \
"Task: Inspect the Helm release cka-nginx, change it to 3 replicas and
service type LoadBalancer, then roll back to the previous revision."
}

scenario_etcd_note() {
  # We do NOT automatically break etcd here; just drop instructions.
  local ns="scenario-etcd"
  info "Creating etcd DR note in namespace $ns"
  create_ns "$ns"

  create_configmap_note "$ns" "lab-note" \
"Task (manual, on control-plane only): 
1. Take an etcd snapshot to /root/etcd-snap.db using etcdctl with TLS.
2. Simulate data loss by removing /var/lib/etcd (lab only).
3. Restore the snapshot into /var/lib/etcd-restore.
4. Update /etc/kubernetes/manifests/etcd.yaml to use the restored data dir.
5. Ensure the control-plane comes back and 'kubectl get nodes' works."
}

main() {
  kubectl_ok

  info "=== Creating CKA drill scenarios ==="
  scenario_crd
  scenario_gateway
  scenario_helm
  scenario_cni_break
  scenario_etcd_note

  info "Done."
  info "Namespaces created:"
  kubectl get ns | grep "scenario-" || true
  info "Check ConfigMaps named 'lab-note' in each scenario namespace for task descriptions."
}

main "$@"
