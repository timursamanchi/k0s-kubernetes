#!/bin/bash

NAMESPACE="quote-app"

check_pod_status() {
  local label=$1
  local component=$2

  echo "🔍 Checking ${component^^} Deployment Status..."
  POD_JSON=$(kubectl get pods -n "$NAMESPACE" -l app=$label -o json 2>/dev/null)

  if [[ $(echo "$POD_JSON" | jq '.items | length') -eq 0 ]]; then
    echo "❌ No pod found for component: $component"
  else
    echo "$POD_JSON" | jq -r '.items[0].status.containerStatuses[0]' | \
      jq --arg comp "$component" '{component: $comp, name: .name, image: .image, ready: .ready, state: .state, lastState: .lastState, restartCount: .restartCount}'
  fi
  echo
}

check_service_status() {
  local label=$1
  local component=$2

  echo "🔍 Checking ${component^^} Service..."
  SVC_JSON=$(kubectl get svc -n "$NAMESPACE" -l app=$label -o json 2>/dev/null)

  if [[ $(echo "$SVC_JSON" | jq '.items | length') -eq 0 ]]; then
    echo "❌ No service found for component: $component"
  else
    echo "$SVC_JSON" | jq --arg comp "$component" '.items[0] | {
      component: $comp,
      name: .metadata.name,
      type: .spec.type,
      clusterIP: .spec.clusterIP,
      ports: [.spec.ports[] | {port: .port, targetPort: .targetPort}]
    }'
  fi
  echo
}

check_pod_status "quote-backend" "backend"
check_service_status "quote-backend" "backend"

check_pod_status "quote-frontend" "frontend"
check_service_status "quote-frontend" "frontend"


kubectl get pods --all-namespaces -l app.kubernetes.io/name=ingress-nginx
echo""
kubectl get pods -n kube-flannel
