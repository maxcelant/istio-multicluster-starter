# Istio Multi-cluster Starter

### Basic Architecture

>![image](https://github.com/user-attachments/assets/4e05f0bc-e09f-4340-9fd4-7b43ca88bb52)

### Prerequisites
- `jq`
- `kind`
- `colima`

### How to run

- Make sure you start your colima VM with the following command:

```bash
colima start --kubernetes -m 10 -c 6
```

**Note**: If you already have a clusters named `kind-east-cluster` and `kind-west-cluster`, then run `./teardown.sh` first.

```bash
> chmod u+x ./startup.sh
> ./startup.sh
```

### Testing Intra-Mesh Communication

Run the following command in your **west** cluster. 

```bash
❯ kubectl --context="kind-east-cluster" -n default exec deploy/sleep -c sleep -- curl -s webapp.istioinaction/api/catalog
```

You should recieve a JSON response.

### Testing Ingress Communication

Once again, make sure you are in the **west** cluster, then run the following command:

```bash
❯ kubectl --context="kind-west-cluster" port-forward deploy/istio-ingressgateway \
-n istio-system 8080:8080
```

Then `curl` to the webapp service.

```bash
❯ curl http://localhost:8080/api/catalog -H "Host: webapp.istioinaction.io"
```
