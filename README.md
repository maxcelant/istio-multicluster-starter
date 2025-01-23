# Istio Multi-cluster Starter

**Note**: If you are running on colima, use `colima start --network-address`

### Steps

1. Create the `kind` clusters: east and west.
2. Setup a metal load-balancer for both clusters.
3. Deploy the `IstioOperator` for each cluster using `istioctl install`.
4. Perform the `create-remote-secret` for each cluster.
5. 
