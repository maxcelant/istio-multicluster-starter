# Istio Multi-cluster Starter

### How to run

**Note**: If you already have a clusters named `kind-east-cluster` and `kind-west-cluster`, then run `./teardown.sh` first.

```bash
> chmod u+x ./startup.sh
> ./startup.sh
```

### Testing

To test intra-mesh communication...

```bash
> kubectl -n default exec deploy/sleep -c sleep -- curl -s webapp.istioinaction/api/catalog
```

You should recieve a JSON response.


