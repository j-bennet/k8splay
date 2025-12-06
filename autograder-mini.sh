#!/usr/bin/env bash

# CKA Mock Exam Auto-Grader (minikube-friendly, no etcd checks)
# Requires: kubectl, jq, helm

TOTAL=0

add_score() {
  local pts=$1
  local msg=$2
  TOTAL=$((TOTAL + pts))
  printf "[OK]  +%2d  %s\n" "$pts" "$msg"
}

fail_score() {
  local pts=$1
  local msg=$2
  printf "[FAIL] +0   %s\n" "$msg"
}

check_ready_node_with_podcidr_10_244() {
  kubectl get nodes -o json 2>/dev/null | jq -e '
    .items[]?
    | select(.status.conditions[]? | .type=="Ready" and .status=="True")
    | .spec.podCIDR // "" | startswith("10.244.")
  ' >/dev/null 2>&1
}

task1() {
  # Task 1: kubeadm-like cluster with pod CIDR 10.244.0.0/16 (best effort on minikube)
  if kubectl get nodes >/dev/null 2>&1; then
    if check_ready_node_with_podcidr_10_244; then
      add_score 4 "Task 1: node Ready with podCIDR 10.244.x.x"
    else
      # On minikube this may not match; still require Ready node
      kubectl get nodes -o json 2>/dev/null | jq -e '
        .items[]? | .status.conditions[]? |
        select(.type=="Ready" and .status=="True")
      ' >/dev/null 2>&1 \
        && add_score 2 "Task 1: cluster Ready (podCIDR not 10.244.x.x)" \
        || fail_score 4 "Task 1: no Ready node"
    fi
  else
    fail_score 4 "Task 1: kubectl get nodes failed"
  fi
}

task2() {
  # Task 2: Calico CNI installed
  if kubectl get pods -n kube-system >/dev/null 2>&1 && \
     kubectl get pods -n kube-system -o json 2>/dev/null | jq -e '
       .items[]? | .metadata.name | test("calico")
     ' >/dev/null 2>&1; then
    add_score 3 "Task 2: Calico pods present in kube-system"
  else
    fail_score 3 "Task 2: Calico pods not detected"
  fi
}

task3() {
  # Task 3: CoreDNS running
  if kubectl get pods -n kube-system -l k8s-app=kube-dns -o json 2>/dev/null | jq -e '
      .items[]? | .status.phase == "Running"
    ' >/dev/null 2>&1; then
    add_score 5 "Task 3: CoreDNS pods running"
  else
    fail_score 5 "Task 3: CoreDNS not fully running"
  fi
}

task4() {
  # Task 4: Deployment app with nodeSelector node=blue and 3 replicas
  local deploy="app"
  if ! kubectl get deploy "$deploy" >/dev/null 2>&1; then
    fail_score 2 "Task 4: Deployment app not found"
    return
  fi

  local replicas
  replicas=$(kubectl get deploy "$deploy" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  local ns_node
  ns_node=$(kubectl get deploy "$deploy" -o jsonpath='{.spec.template.spec.nodeSelector.node}' 2>/dev/null)

  if [[ "$replicas" == "3" ]] && [[ "$ns_node" == "blue" ]]; then
    add_score 2 "Task 4: app deployment replicas=3 and nodeSelector=node=blue"
  else
    fail_score 2 "Task 4: replicas or nodeSelector mismatch"
  fi
}

task5() {
  # Task 5: CronJob hello every minute
  if ! kubectl get cronjob hello >/dev/null 2>&1; then
    fail_score 3 "Task 5: CronJob hello not found"
    return
  fi

  local schedule
  schedule=$(kubectl get cronjob hello -o jsonpath='{.spec.schedule}' 2>/dev/null)
  if [[ "$schedule" != "* * * * *" ]]; then
    fail_score 3 "Task 5: CronJob schedule is not every minute"
    return
  fi

  local succ
  succ=$(kubectl get cronjob hello -o jsonpath='{.status.lastScheduleTime}' 2>/dev/null)
  if [[ -n "$succ" ]]; then
    add_score 3 "Task 5: CronJob hello scheduled and running"
  else
    fail_score 3 "Task 5: CronJob hello has not run yet"
  fi
}

task6() {
  # Task 6: Deployment store with resources
  if ! kubectl get deploy store >/dev/null 2>&1; then
    fail_score 2 "Task 6: Deployment store not found"
    return
  fi

  local req_cpu req_mem lim_cpu lim_mem
  req_cpu=$(kubectl get deploy store -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
  req_mem=$(kubectl get deploy store -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null)
  lim_cpu=$(kubectl get deploy store -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}' 2>/dev/null)
  lim_mem=$(kubectl get deploy store -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null)

  if [[ "$req_cpu" == "100m" && "$req_mem" == "64Mi" && "$lim_cpu" == "200m" && "$lim_mem" == "128Mi" ]]; then
    add_score 2 "Task 6: store deployment resource requests/limits set"
  else
    fail_score 2 "Task 6: store resources mismatch"
  fi
}

task7() {
  # Task 7: DaemonSet logger on workers only (heuristic)
  if ! kubectl get ds logger >/dev/null 2>&1; then
    fail_score 3 "Task 7: DaemonSet logger not found"
    return
  fi

  local desired current
  desired=$(kubectl get ds logger -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null)
  current=$(kubectl get ds logger -o jsonpath='{.status.currentNumberScheduled}' 2>/dev/null)

  if [[ "$desired" == "$current" && "$desired" -gt 0 ]]; then
    add_score 3 "Task 7: logger DaemonSet pods scheduled"
  else
    fail_score 3 "Task 7: logger DaemonSet not fully scheduled"
  fi
}

task8() {
  # Task 8: NodePort service api on 31080
  if ! kubectl get svc api >/dev/null 2>&1; then
    fail_score 2 "Task 8: Service api not found"
    return
  fi

  local np
  np=$(kubectl get svc api -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
  if [[ "$np" == "31080" ]]; then
    add_score 2 "Task 8: api service NodePort=31080"
  else
    fail_score 2 "Task 8: api service NodePort not 31080"
  fi
}

task9() {
  # Task 9: HTTPRoute Accepted=True
  if ! kubectl get httproute >/dev/null 2>&1; then
    fail_score 6 "Task 9: No HTTPRoute found"
    return
  fi

  if kubectl get httproute -A -o json 2>/dev/null | jq -e '
      .items[]?.status.parents[]? | .conditions[]? |
      select(.type=="Accepted" and .status=="True")
    ' >/dev/null 2>&1; then
    add_score 6 "Task 9: HTTPRoute with Accepted=True found"
  else
    fail_score 6 "Task 9: No HTTPRoute with Accepted=True"
  fi
}

task10() {
  # Task 10: NetworkPolicy frontend -> backend (role=db)
  if ! kubectl get networkpolicy -A >/dev/null 2>&1; then
    fail_score 4 "Task 10: No NetworkPolicies found"
    return
  fi

  if kubectl get networkpolicy -n backend -o json 2>/dev/null | jq -e '
      .items[]? |
      select(.spec.podSelector.matchLabels.role=="db") |
      .spec.ingress[]?.from[]? |
      select(.namespaceSelector.matchLabels."kubernetes.io/metadata.name"=="frontend" or .namespaceSelector.matchLabels.name=="frontend")
    ' >/dev/null 2>&1; then
    add_score 4 "Task 10: NetworkPolicy allowing frontend -> backend db found"
  else
    fail_score 4 "Task 10: Matching NetworkPolicy not detected"
  fi
}

task11() {
  # Task 11: No pods stuck in ContainerCreating
  if kubectl get pods -A >/dev/null 2>&1 && \
     ! kubectl get pods -A 2>/dev/null | grep -q "ContainerCreating"; then
    add_score 3 "Task 11: No pods stuck in ContainerCreating"
  else
    fail_score 3 "Task 11: Pods still stuck in ContainerCreating"
  fi
}

task12() {
  # Task 12: PVC data and pod using it
  if ! kubectl get pvc data >/dev/null 2>&1; then
    fail_score 3 "Task 12: PVC data not found"
    return
  fi

  local phase
  phase=$(kubectl get pvc data -o jsonpath='{.status.phase}' 2>/dev/null)
  if [[ "$phase" != "Bound" ]]; then
    fail_score 3 "Task 12: PVC data not Bound"
    return
  fi

  if kubectl get pods -A -o json 2>/dev/null | jq -e '
      .items[]? |
      select(.spec.volumes[]? | .persistentVolumeClaim.claimName=="data") |
      select(.status.phase=="Running")
    ' >/dev/null 2>&1; then
    add_score 3 "Task 12: PVC data bound and used by running pod"
  else
    fail_score 3 "Task 12: No running pod using PVC data"
  fi
}

task13() {
  # Task 13: StorageClass fast as default with no-provisioner
  if ! kubectl get sc fast >/dev/null 2>&1; then
    fail_score 4 "Task 13: StorageClass fast not found"
    return
  fi

  local provisioner default
  provisioner=$(kubectl get sc fast -o jsonpath='{.provisioner}' 2>/dev/null)
  default=$(kubectl get sc fast -o jsonpath='{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}' 2>/dev/null)

  if [[ "$provisioner" == "kubernetes.io/no-provisioner" && "$default" == "true" ]]; then
    add_score 4 "Task 13: StorageClass fast is default and uses no-provisioner"
  else
    fail_score 4 "Task 13: fast SC not default or wrong provisioner"
  fi
}

task14() {
  # Task 14: VolumeSnapshot for PVC data (if CRDs present)
  if ! kubectl api-resources | grep -q volumesnapshots.snapshot.storage.k8s.io; then
    fail_score 3 "Task 14: VolumeSnapshot CRD not available"
    return
  fi

  if kubectl get volumesnapshot -A >/dev/null 2>&1 && \
     kubectl get volumesnapshot -A -o json 2>/dev/null | jq -e '
       .items[]? | .spec.source.persistentVolumeClaimName=="data"
     ' >/dev/null 2>&1; then
    add_score 3 "Task 14: VolumeSnapshot for PVC data found"
  else
    fail_score 3 "Task 14: No VolumeSnapshot for PVC data"
  fi
}

task15() {
  # Task 15: Helm repo and release web
  if ! command -v helm >/dev/null 2>&1; then
    fail_score 3 "Task 15: helm not installed"
    return
  fi

  if helm repo list 2>/dev/null | grep -q bitnami && \
     helm list -A 2>/dev/null | grep -q "web"; then
    add_score 3 "Task 15: Bitnami repo added and web release present"
  else
    fail_score 3 "Task 15: Bitnami repo or web release missing"
  fi
}

task16() {
  # Task 16: Helm upgrade + rollback for web
  if ! command -v helm >/dev/null 2>&1; then
    fail_score 4 "Task 16: helm not installed"
    return
  fi

  if ! helm history web >/dev/null 2>&1; then
    fail_score 4 "Task 16: helm history web missing"
    return
  fi

  local revisions
  revisions=$(helm history web -o json 2>/dev/null | jq 'length' 2>/dev/null)
  if [[ "$revisions" -ge 2 ]]; then
    add_score 4 "Task 16: web release has multiple revisions (upgrade+rollback done)"
  else
    fail_score 4 "Task 16: web release does not show multiple revisions"
  fi
}

task17() {
  # Task 17: Helm values override for image.tag and service.type
  if ! command -v helm >/dev/null 2>&1; then
    fail_score 3 "Task 17: helm not installed"
    return
  fi

  if ! helm list -A 2>/dev/null | grep -q "web"; then
    fail_score 3 "Task 17: web release not found"
    return
  fi

  local tag stype
  tag=$(helm get values web -o json 2>/dev/null | jq -r '..|.tag? // empty' 2>/dev/null | head -n1)
  stype=$(helm get values web -o json 2>/dev/null | jq -r '..|.type? // empty' 2>/dev/null | head -n1)

  if [[ "$tag" == "latest" && "$stype" == "ClusterIP" ]]; then
    add_score 3 "Task 17: web release uses tag=latest and service.type=ClusterIP"
  else
    fail_score 3 "Task 17: values override not detected on web release"
  fi
}

task20() {
  # Task 20: ServiceAccount auditor read-only for pods cluster-wide
  if ! kubectl get sa auditor >/dev/null 2>&1; then
    fail_score 3 "Task 20: ServiceAccount auditor not found"
    return
  fi

  if kubectl auth can-i --as=system:serviceaccount:default:auditor get pods --all-namespaces >/dev/null 2>&1 && \
     ! kubectl auth can-i --as=system:serviceaccount:default:auditor delete pods --all-namespaces >/dev/null 2>&1; then
    add_score 3 "Task 20: auditor can get pods but not delete (read-only)"
  else
    fail_score 3 "Task 20: RBAC for auditor not correctly configured"
  fi
}

main() {
  echo "Running CKA Mock Exam Auto-Grader (no etcd checks)"
  echo

  task1
  task2
  task3
  task4
  task5
  task6
  task7
  task8
  task9
  task10
  task11
  task12
  task13
  task14
  task15
  task16
  task17
  task20

  echo
  echo "Total Score: $TOTAL / 85"
}

main "$@"

