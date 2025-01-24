# Istio Multi-cluster Starter

**Note**: If you are running on colima, use `colima start --network-address`

### Steps

1. Create the `kind` clusters: east and west.
2. Setup a metal load-balancer for both clusters.
3. Deploy the `IstioOperator` for each cluster using `istioctl install`.
4. Perform the `create-remote-secret` for each cluster.
5. 

### Where we left off...

Correctly updatrre the IP range for the loadbalancer

```
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: west-cluster-pool
  namespace: metallb-system
spec:
  addresses:
  - 172.18.0.100-172.18.0.200

```

Try adding a 

```
docker run --rm --network kind --publish 172.18.0.100:80:80 nginx
```

to port-forward the kind network
