# !/bin/sh

set -euo pipefail

METALLB_VERSION="v0.13.10"

mkdir generated > /dev/null 2>&1 || true

regions=("east" "west")

for i in "${!regions[@]}"; do
  export i  
  export region="${regions[i]}"  
  envsubst < kubernetes/config.yaml > generated/cluster-config-${i}.yaml
  envsubst < istio/cluster.yaml > generated/istio-config-${region}.yaml
  kind create cluster --config "generated/cluster-config-${i}.yaml" --name ${region}-cluster || echo "${region} cluster already created, skipping this step."
done


