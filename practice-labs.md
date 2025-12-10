# CKA Focus Labs (CRDs, Gateway, CNI, Helm, etcd)

Prereqs:

- A practice cluster (kind or kubeadm), `kubectl` + `helm` installed
- Cluster-admin access
- For etcd lab: kubeadm control-plane with static pods

---

## Lab 0 — Cluster Setup

### kind (single-node)

```bash
kind create cluster --name cka-lab
kubectl config use-context kind-cka-lab
````

Docs:

* [https://kind.sigs.k8s.io/docs/user/quick-start/](https://kind.sigs.k8s.io/docs/user/quick-start/)

### kubeadm (optional, for etcd)

Docs:

* [https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)

---

## Lab 1 — CRD & Custom Resource

**Goal:** Install a CRD, create CRs, inspect fields.

1. Create CRD:

```bash
cat <<EOF > crd-widget.yaml
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

kubectl apply -f crd-widget.yaml
kubectl get crd widgets.example.com
```

2. Inspect schema:

```bash
kubectl explain widget.spec --recursive
kubectl explain widget.spec.size
```

3. Create a CR:

```bash
kubectl apply -f - <<EOF
apiVersion: example.com/v1
kind: Widget
metadata:
  name: sample-widget
spec:
  size: large
EOF

kubectl get widgets
kubectl get widget sample-widget -o yaml
kubectl describe widget sample-widget
```

Variation: create an invalid CR (`size: huge`) and see validation fail.

Docs:

* [https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/)

---

## Lab 2 — Ingress → Gateway Migration

**Goal:** Migrate a simple HTTP app from Ingress to Gateway API.

1. Install Gateway API:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/latest/download/standard-install.yaml
kubectl get crd | grep gateway
```

Docs:

* [https://gateway-api.sigs.k8s.io/](https://gateway-api.sigs.k8s.io/)

2. Deploy sample app + Ingress:

```bash
kubectl create ns gw-lab
kubectl -n gw-lab create deployment web --image=nginx --replicas=2
kubectl -n gw-lab expose deployment web --port=80 --target-port=80

kubectl -n gw-lab apply -f - <<EOF
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
```

3. Migrate to Gateway:

* Create `GatewayClass`
* Create `Gateway`
* Create `HTTPRoute` equivalent to the Ingress above

Example templates:

* Simple example: [https://gateway-api.sigs.k8s.io/guides/simple-example/](https://gateway-api.sigs.k8s.io/guides/simple-example/)
* Migration guide: [https://gateway-api.sigs.k8s.io/guides/migrating-from-ingress/](https://gateway-api.sigs.k8s.io/guides/migrating-from-ingress/)

Check:

```bash
kubectl get gatewayclass,gateway,httproute -A -o wide
kubectl describe httproute -n gw-lab web
```

---

## Lab 3 — CNI Provider Install & Troubleshooting

**Goal:** Install a CNI on a kubeadm cluster and diagnose NotReady nodes.

> Do this on a fresh kubeadm control-plane where CNI is not yet installed.

1. After `kubeadm init`, verify nodes:

```bash
kubectl get nodes
# likely NotReady due to missing CNI
kubectl get pods -n kube-system
```

2. Install Calico (example):

```bash
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
kubectl get pods -n calico-system
kubectl get nodes
```

3. Break CNI on purpose:

```bash
kubectl -n calico-system scale ds calico-node --replicas=0
kubectl get nodes
kubectl get pods -n calico-system
```

4. Fix it:

```bash
kubectl -n calico-system scale ds calico-node --replicas=1
kubectl get nodes
```

Alternative CNIs:

* Flannel: [https://github.com/flannel-io/flannel](https://github.com/flannel-io/flannel)
* Cilium: [https://docs.cilium.io/en/stable/gettingstarted/](https://docs.cilium.io/en/stable/gettingstarted/)

---

## Lab 4 — Helm Fundamentals

**Goal:** Add repo, install chart, upgrade, rollback, uninstall.

1. Add repo + search:

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm search repo nginx
```

2. Install:

```bash
helm install mynginx bitnami/nginx \
  --set service.type=ClusterIP

helm list
kubectl get pods
kubectl get svc
```

3. Inspect + upgrade:

```bash
helm get values mynginx
helm upgrade mynginx bitnami/nginx \
  --set replicaCount=3

helm history mynginx
```

4. Rollback + uninstall:

```bash
helm rollback mynginx 1
helm uninstall mynginx
```

Docs:

* [https://helm.sh/docs/intro/using_helm/](https://helm.sh/docs/intro/using_helm/)

---

## Lab 5 — etcd Backup & Disaster Recovery (kubeadm)

**Goal:** Take snapshot, restore into new data dir, update static pod.

> Run these on the control-plane node. Adjust paths if your distro differs.

1. Identify etcd manifest and certs:

```bash
ls -l /etc/kubernetes/manifests/etcd.yaml
ls -l /etc/kubernetes/pki/etcd
```

2. Take snapshot:

```bash
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /root/etcd-snapshot.db

ls -lh /root/etcd-snapshot.db
```

3. Stop kubelet (for a full break/restore) **only on a dedicated lab node**:

```bash
systemctl stop kubelet
```

4. Restore into a new data dir:

```bash
rm -rf /var/lib/etcd-restored
ETCDCTL_API=3 etcdctl snapshot restore /root/etcd-snapshot.db \
  --data-dir=/var/lib/etcd-restored
```

5. Edit `/etc/kubernetes/manifests/etcd.yaml`:

* Change any `--data-dir=/var/lib/etcd` to `/var/lib/etcd-restored`
* Ensure hostPath for data dir matches `/var/lib/etcd-restored`

6. Start kubelet:

```bash
systemctl start kubelet
```

7. Verify:

```bash
kubectl get nodes
kubectl get pods -A
```

Docs:

* [https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/#disaster-recovery](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/#disaster-recovery)

---

## Lab 6 — Speed Drills

Run selected labs again with a timer:

* Target **5–7 minutes** for smaller tasks (CRD, Helm)
* Target **10–15 minutes** for etcd restore

