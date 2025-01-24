# !/bin/sh

set -euo pipefail

kind delete cluster --name east-cluster
kind delete cluster --name west-cluster
