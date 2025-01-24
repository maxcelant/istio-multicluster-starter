# !/bin/sh

set -euo pipefail

METALLB_VERSION="v0.13.10"

mkdir generated > /dev/null 2>&1 || true

regions=("east" "west")

for i in "${!regions[@]}"; do
  export i  
  export region="${regions[i]}"  
  envsubst < kubernetes/config.yaml > generated/cluster-config-${region}.yaml
  envsubst < istio/cluster.yaml > generated/istio-config-${region}.yaml
  kind create cluster --config "generated/cluster-config-${region}.yaml" --name ${region}-cluster || echo "${region} cluster already created, skipping this step."
  istioctl install --context "kind-${region}-cluster" --force -y -f "generated/istio-config-${region}.yaml"
  kubectl apply --context "kind-${region}-cluster" -f "istio/gateway.yaml"
done


