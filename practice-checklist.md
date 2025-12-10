# **CKA 10-Day Practice Checklist**

## **Day 1 — Cluster Setup**

* [-] Create a kind cluster
* [x] Create a kubeadm cluster
* [x] Inspect `/etc/kubernetes/manifests`
* [x] Reset and recreate cluster

---

## **Day 2 — CRDs + Custom Resources**

* [x] Install a CRD from YAML
* [x] Verify CRD: `kubectl get crd`
* [x] Explore schema: `kubectl explain <crd> --recursive`
* [x] Create CR instance
* [x] Inspect CR: `kubectl get -o yaml`, `kubectl describe`

---

## **Day 3 — Gateway API Basics**

* [x] Install Gateway API CRDs
* [x] Install a Gateway controller (Cilium)
* [-] Create GatewayClass
* [x] Create Gateway
* [x] Create simple HTTPRoute
* [x] Route traffic to a backend

---

## **Day 4 — Gateway API Deep Dive**

* [ ] Path matching
* [ ] TLS
* [ ] Traffic splitting
* [ ] Conditions/events on Gateway
* [ ] Debug broken route

---

## **Day 5 — CNI Providers**

* [ ] Install Calico on a fresh cluster
* [ ] Install Flannel on a fresh cluster
* [ ] Fix `NotReady` nodes due to missing CNI
* [ ] Troubleshoot CNI pods

---

## **Day 6 — Helm**

* [ ] Add repo
* [ ] Search repo
* [ ] Install a chart
* [ ] Show values
* [ ] Upgrade chart
* [ ] Roll back
* [ ] Uninstall

---

## **Day 7 — etcd Backup + Recovery**

* [ ] Take live snapshot
* [ ] Restore snapshot to new data dir
* [ ] Update `etcd.yaml` static pod manifest
* [ ] Confirm etcd + API server working

---

## **Day 8 — Speed Drills**

* [ ] Solve 5 tasks in ≤5 minutes each
* [ ] Practice Helm tasks fast
* [ ] Practice CRD/CR exploration fast
* [ ] Practice Gateway API creation fast

---

## **Day 9 — Mock Exam**

* [ ] Finish all 12 tasks
* [ ] Finish within 80 minutes
* [ ] Note weak areas

---

## **Day 10 — Fix Weak Spots**

* [ ] Re-do failed mock tasks
* [ ] Repeat etcd restore until automatic
* [ ] Install CNIs from memory
* [ ] Migrate Ingress → HTTPRoute without notes

