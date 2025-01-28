# !/bin/sh

set -euo pipefail

METALLB_VERSION="v0.14.15"
CERTMANAGER_VERSION="v1.16.3"

kind create cluster --config "cluster/cluster-east.yaml" --name east-cluster || echo "Cluster already created."
kind create cluster --config "cluster/cluster-west.yaml" --name west-cluster || echo "Cluster already created."

alias keast='kubectl --context="kind-east-cluster"'
alias kwest='kubectl --context="kind-west-cluster"'

keast apply -f https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/config/manifests/metallb-native.yaml
keast rollout status deploy -n metallb-system controller
kwest apply -f https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/config/manifests/metallb-native.yaml
kwest rollout status deploy -n metallb-system controller

keast apply -f metallb/east-lb.yaml
kwest apply -f metallb/west-lb.yaml

keast create ns cert-manager
keast apply -f https://github.com/cert-manager/cert-manager/releases/download/${CERTMANAGER_VERSION}/cert-manager.yaml
kwest create ns cert-manager
kwest apply -f https://github.com/cert-manager/cert-manager/releases/download/${CERTMANAGER_VERSION}/cert-manager.yaml

kwest create namespace istio-system 
kwest create secret generic cacerts -n istio-system \
    --from-file=certs/west-cluster/ca-cert.pem \
    --from-file=certs/west-cluster/ca-key.pem \
    --from-file=certs/root-cert.pem \
    --from-file=certs/west-cluster/cert-chain.pem 

keast create namespace istio-system 
keast create secret generic cacerts -n istio-system \
    --from-file=certs/east-cluster/ca-cert.pem \
    --from-file=certs/east-cluster/ca-key.pem \
    --from-file=certs/root-cert.pem \
    --from-file=certs/east-cluster/cert-chain.pem 

kwest label namespace istio-system \
    topology.istio.io/network="west-network"

keast label namespace istio-system \
    topology.istio.io/network="east-network"

istioctl --context="kind-east-cluster" install -y -f controlplanes/cluster-east.yaml
istioctl --context="kind-west-cluster" install -y -f controlplanes/cluster-west.yaml

kwest create ns istioinaction
kwest label namespace istioinaction istio-injection=enabled
kwest -n istioinaction apply -f apps/webapp-deployment-svc.yaml
kwest -n istioinaction apply -f apps/webapp-gw-vs.yaml
kwest -n istioinaction apply -f apps/catalog-svc.yaml
kwest -n default apply -f apps/sleep.yaml

keast create ns istioinaction
keast label namespace istioinaction istio-injection=enabled
keast -n istioinaction apply -f apps/catalog.yaml
keast -n default apply -f apps/sleep.yaml

WEST_CLUSTER_ID=$(docker ps --filter "name=west-cluster" --format "{{.ID}}")
EAST_CLUSTER_ID=$(docker ps --filter "name=east-cluster" --format "{{.ID}}")
WEST_CLUSTER_IP=$(docker inspect $WEST_CLUSTER_ID | jq -r '.[0].NetworkSettings.Networks.kind.IPAddress')
EAST_CLUSTER_IP=$(docker inspect $EAST_CLUSTER_ID | jq -r '.[0].NetworkSettings.Networks.kind.IPAddress')

istioctl create-remote-secret --name="east-cluster" --context="kind-east-cluster" --server="https://${EAST_CLUSTER_IP}:6443" | kwest apply -f -
istioctl create-remote-secret --name="west-cluster" --context="kind-west-cluster" --server="https://${WEST_CLUSTER_IP}:6443" | keast apply -f -

istioctl install --context="kind-east-cluster" -y -f gateways/east-gw.yaml
istioctl install --context="kind-west-cluster" -y -f gateways/west-gw.yaml

kwest apply -n istio-system -f cert-manager/certificate.yaml
keast apply -n istio-system -f cert-manager/certificate.yaml

kwest apply -n istio-system -f cert-manager/issuer-west.yaml
keast apply -n istio-system -f cert-manager/issuer-east.yaml

kwest apply -n istio-system -f gateways/expose-services.yaml
keast apply -n istio-system -f gateways/expose-services.yaml
