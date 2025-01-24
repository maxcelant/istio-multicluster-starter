# !/bin/sh

set -euo pipefail

kind create cluster --config "book/cluster/cluster-east.yaml" --name east-cluster || echo "Cluster already created."
kind create cluster --config "book/cluster/cluster-west.yaml" --name west-cluster || echo "Cluster already created."

alias keast='kubectl --context="kind-east-cluster"'
alias kwest='kubectl --context="kind-west-cluster"'

kwest create namespace istio-system || true
kwest create secret generic cacerts -n istio-system \
    --from-file=book/certs/west-cluster/ca-cert.pem \
    --from-file=book/certs/west-cluster/ca-key.pem \
    --from-file=book/certs/root-cert.pem \
    --from-file=book/certs/west-cluster/cert-chain.pem || true

keast create namespace istio-system || true
keast create secret generic cacerts -n istio-system \
    --from-file=book/certs/east-cluster/ca-cert.pem \
    --from-file=book/certs/east-cluster/ca-key.pem \
    --from-file=book/certs/root-cert.pem \
    --from-file=book/certs/east-cluster/cert-chain.pem || true

kwest label namespace istio-system \
    topology.istio.io/network="west-network"

keast label namespace istio-system \
    topology.istio.io/network="east-network"

istioctl --context="kind-east-cluster" install -y -f book/controlplanes/cluster-east.yaml
istioctl --context="kind-west-cluster" install -y -f book/controlplanes/cluster-west.yaml

kwest create ns test
kwest label namespace test istio-injection=enabled
kwest -n test apply -f book/apps/webapp-deployment-svc.yaml
kwest -n test apply -f book/apps/webapp-gw-vs.yaml
kwest -n test apply -f book/apps/catalog-svc.yaml

keast create ns test
keast label namespace test istio-injection=enabled
keast -n test apply -f book/apps/catalog.yaml

WEST_NETWORK_IP=$(docker ps --format 'json' | jq -r '.Ports' | sed -n '1p' | cut -f1 -d "-")
EAST_NETWORK_IP=$(docker ps --format 'json' | jq -r '.Ports' | sed -n '2p' | cut -f1 -d "-")

istioctl create-remote-secret --name="east-cluster" --context="kind-east-cluster" --server="https://${EAST_NETWORK_IP}" | kwest apply -f -
istioctl create-remote-secret --name="west-cluster" --context="kind-west-cluster" --server="https://${WEST_NETWORK_IP}" | keast apply -f -