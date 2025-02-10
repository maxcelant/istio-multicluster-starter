# !/bin/sh

set -euo pipefail

CERTMANAGER_VERSION="v1.16.3"

both_context() {
  for region in {east,west}; do 
    cmd=$(echo $1 | sed "s/{REGION}/${region}/g")
    eval "$cmd --context='kind-${region}-cluster'"
  done
}

kind create cluster --config "cluster/cluster-east.yaml" --name east-cluster || echo "Cluster already created."
kind create cluster --config "cluster/cluster-west.yaml" --name west-cluster || echo "Cluster already created."

both_context "kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/main/config/manifests/metallb-native.yaml"
both_context "kubectl rollout status deploy -n metallb-system controller"
both_context "kubectl apply -f metallb/{REGION}-lb.yaml"
both_context "kubectl create namespace cert-manager"
both_context "kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/${CERTMANAGER_VERSION}/cert-manager.yaml"
both_context "kubectl create namespace istio-system"
both_context "kubectl label namespace istio-system topology.istio.io/network='{REGION}-network'"
both_context "kubectl apply -f cert-manager/vault-token-secret.yaml"
both_context "istioctl install -y -f controlplanes/cluster-{REGION}.yaml"
both_context "kubectl create namespace istioinaction"
both_context "kubectl label namespace istioinaction istio-injection=enabled"
both_context "kubectl -n istioinaction apply -f apps/webapp-deployment-svc.yaml"
both_context "kubectl -n istioinaction apply -f apps/webapp-gw-vs.yaml"
both_context "kubectl -n istioinaction apply -f apps/catalog-svc.yaml"
kubectl -n istioinaction --context="kind-east-cluster" apply -f apps/catalog.yaml
both_context "kubectl -n default apply -f apps/sleep.yaml"

(
  cd vault
  docker-compose up -d
  sleep 5
)

both_context "kubectl create configmap coredns --from-file=cluster/coredns.yaml -n kube-system --save-config --dry-run=client -o yaml | kubectl apply -f -"
both_context "kubectl apply -f cert-manager/issuer-{REGION}.yaml"

WEST_CLUSTER_ID=$(docker ps --filter "name=west-cluster" --format "{{.ID}}")
EAST_CLUSTER_ID=$(docker ps --filter "name=east-cluster" --format "{{.ID}}")
WEST_CLUSTER_IP=$(docker inspect $WEST_CLUSTER_ID | jq -r '.[0].NetworkSettings.Networks.kind.IPAddress')
EAST_CLUSTER_IP=$(docker inspect $EAST_CLUSTER_ID | jq -r '.[0].NetworkSettings.Networks.kind.IPAddress')
istioctl create-remote-secret --name="east-cluster" --context="kind-east-cluster" --server="https://${EAST_CLUSTER_IP}:6443" | kubectl --context="kind-west-cluster" apply -f -
istioctl create-remote-secret --name="west-cluster" --context="kind-west-cluster" --server="https://${WEST_CLUSTER_IP}:6443" | kubectl --context="kind-east-cluster" apply -f -
both_context "istioctl install -y -f gateways/{REGION}-gw.yaml"
both_context "kubectl apply -n istio-system -f cert-manager/certificate.yaml"
both_context "kubectl apply -n istio-system -f gateways/expose-services.yaml"

