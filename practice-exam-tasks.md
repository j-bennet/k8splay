# **CKA Full-Length Mock Exam (20 Tasks / 120 Minutes / 100 Points)**

---

# **Section 1 — Cluster Architecture (12 pts)**

---

### **1. Create a new kubeadm cluster**

**Difficulty:** Medium — **4 pts**
**Task:**
Create a single-control-plane kubeadm cluster with pod CIDR `10.244.0.0/16`.
**Passing:**
`kubectl get nodes` shows the cluster is Ready.
**Evidence:** node list.

---

### **2. Install a CNI (Calico)**

**Difficulty:** Easy — **3 pts**
**Task:**
Install Calico so nodes become Ready.
**Passing:**
All nodes show `Ready` within 3 min.
**Evidence:** `kubectl get pods -n kube-system`.

---

### **3. Fix CoreDNS**

**Difficulty:** Medium — **5 pts**
**Task:**
CoreDNS is stuck in `CrashLoopBackoff`. Fix it without reinstalling cluster.
**Hint:** check image pull errors, `kube-proxy`, CNI, configmap.
**Passing:**
`kubectl get pods -n kube-system` shows CoreDNS Running.
**Evidence:** pod list.

---

# **Section 2 — Workloads & Scheduling (10 pts)**

---

### **4. Create a Deployment with nodeSelector**

**Difficulty:** Easy — **2 pts**
**Task:**
Label one worker node:
`node=blue`
Create a Deployment `app` with 3 replicas restricted to that node.
**Passing:**
All 3 pods scheduled on labeled node.
**Evidence:** `kubectl get pods -o wide`.

---

### **5. Create a CronJob**

**Difficulty:** Medium — **3 pts**
**Task:**
CronJob `hello` runs every minute and prints “hi”.
**Passing:**
At least one job pod finishes.
**Evidence:** pod logs.

---

### **6. Configure Pod resource limits**

**Difficulty:** Easy — **2 pts**
**Task:**
Modify existing deployment `store` to include:

* requests: cpu 100m, mem 64Mi
* limits: cpu 200m, mem 128Mi
  **Passing:**
  `kubectl get deploy store -o yaml` shows limits.
  **Evidence:** deployment YAML.

---

### **7. Create a DaemonSet**

**Difficulty:** Medium — **3 pts**
**Task:**
DaemonSet `logger` runs nginx on all nodes except master (use nodeSelector or taints).
**Passing:**
1 pod on each worker.
**Evidence:** `kubectl get pods -o wide`.

---

# **Section 3 — Services & Networking (15 pts)**

---

### **8. Create a NodePort service**

**Difficulty:** Easy — **2 pts**
**Task:**
Expose Deployment `api` on NodePort 31080.
**Passing:**
`kubectl get svc api` shows given port.
**Evidence:** svc output.

---

### **9. Migrate an Ingress to Gateway API**

**Difficulty:** Hard — **6 pts**
**Task:**
You are given an Ingress:

* host: `shop.example.com`
* backend: service `shop`, port 80

Convert to Gateway API using:

* GatewayClass `demo` (create if missing)
* Gateway `web-gw` in ns `web`
* HTTPRoute serving the same rules

**Passing:**
`kubectl get httproute` shows `Accepted=True`.
**Evidence:** output of HTTPRoute yaml.

---

### **10. NetworkPolicy**

**Difficulty:** Medium — **4 pts**
**Task:**
Allow pods in namespace `frontend` to access pods labeled `role=db` in namespace `backend`. Deny all others.
**Passing:**
Policy exists and matches rules.
**Evidence:** Policy YAML.

---

### **11. Troubleshoot Pod stuck in ContainerCreating**

**Difficulty:** Medium — **3 pts**
**Task:**
Fix a pod failing because of missing CNI or wrong mount.
**Passing:**
Pod becomes Running.
**Evidence:** describe output before/after.

---

# **Section 4 — Storage (10 pts)**

---

### **12. Create a PVC + Pod**

**Difficulty:** Easy — **3 pts**
**Task:**
Create PVC `data` (1Gi). Create a Pod mounting it at `/data`.
**Passing:**
Pod runs and shows `/data` is writable.
**Evidence:** pod logs or exec output.

---

### **13. Configure a StorageClass**

**Difficulty:** Medium — **4 pts**
**Task:**
Create default StorageClass `fast` using `kubernetes.io/no-provisioner` for local PVs.
**Passing:**
SC is default and functional.
**Evidence:** SC yaml.

---

### **14. Create a snapshot (CSI if available)**

**Difficulty:** Medium — **3 pts**
**Task:**
Create a VolumeSnapshot of PVC `data`.
**Passing:** snapshot object exists.
**Evidence:** `kubectl get volumesnapshot`.

---

# **Section 5 — Helm & Package Management (10 pts)**

---

### **15. Add a Helm repo & install chart**

**Difficulty:** Easy — **3 pts**
**Task:**
Add Bitnami repo, install `bitnami/nginx` as release `web`.
**Passing:**
`helm list` shows release.
**Evidence:** helm output.

---

### **16. Helm upgrade + rollback**

**Difficulty:** Medium — **4 pts**
**Task:**
Upgrade `web` release, changing replicaCount to 2.
Rollback to previous revision.
**Passing:**
Rollback works.
**Evidence:** `helm history web`.

---

### **17. Create a Helm values override file**

**Difficulty:** Easy — **3 pts**
**Task:**
Write `values.yaml` changing:

* image.tag to “latest”
* service.type to “ClusterIP”
  Install chart with that config.
  **Passing:**
  Chart installed with those values.
  **Evidence:** `helm get values`.

---

# **Section 6 — etcd, Security, & Troubleshooting (23 pts)**

---

### **18. etcd Snapshot**

**Difficulty:** Medium — **5 pts**
**Task:**
Take a live etcd snapshot to `/root/snap.db`.
**Passing:**
File exists + valid snapshot.
**Evidence:** etcdctl output.

---

### **19. etcd Restore**

**Difficulty:** Hard — **10 pts**
**Task:**
Restore snapshot into `/var/lib/etcd-restore` and update static pod manifest.
Restart control plane.
**Passing:**
API server and etcd come up.
**Evidence:** `kubectl get nodes`.

---

### **20. Create a ServiceAccount + RBAC rule**

**Difficulty:** Medium — **3 pts**
**Task:**
ServiceAccount `auditor` with read-only access to Pods cluster-wide.
**Passing:**
`kubectl auth can-i --as=system:serviceaccount:default:auditor get pods` = yes.
**Evidence:** command result.

---

# **Scoring**

| Section              | Points  |
| -------------------- | ------- |
| Cluster Architecture | 12      |
| Workloads            | 10      |
| Networking           | 15      |
| Storage              | 10      |
| Helm                 | 10      |
| etcd/Security        | 23      |
| **Total**            | **100** |

Passing recommendation: **≥ 75 points**
Target for comfort: **≥ 85 points**

---

# **Scoring Sheet (copy/paste for tracking)**

```
Task 1: /4
Task 2: /3
Task 3: /5
Task 4: /2
Task 5: /3
Task 6: /2
Task 7: /3
Task 8: /2
Task 9: /6
Task 10: /4
Task 11: /3
Task 12: /3
Task 13: /4
Task 14: /3
Task 15: /3
Task 16: /4
Task 17: /3
Task 18: /5
Task 19: /10
Task 20: /3
Total: /100
```

