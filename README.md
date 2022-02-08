# How to use this repo

## Summary

This is a proof of concept where we use Hashicorp Vault CSI and mount it to a sample app.

## Dependencies & Configurations

- kubectl
- kind - kind cluster CLI
- flux - FluxCD to sync the helm charts of Vault
- gh - github CLI to authenticate with the GitHub repo
- vault (optional - only needed if you want to interact with Hashicorp Vault outside the cluster

- Fork the [vault-ha-raft-csi-fluxcd](https://github.com/deeproute/vault-ha-raft-csi-fluxcd) repo to your github.
- In `bootstrap.sh` in [this line](https://github.com/deeproute/vault-ha-raft-csi-fluxcd/blob/main/bootstrap.sh#L34), change to your github user.

## Run this script and follow the instructions
```sh
./bootstrap.sh
```

## Test with a sample app


- Enable kubernetes auth in Vault:

```sh
kubectl -n vault-server exec -it vault-server-0 -- /bin/sh

$ vault login
Token (will be hidden): <copy root token from vault_cred.json>
Success! You are now authenticated. The token information displayed below
(...)

$ vault auth enable kubernetes
Success! Enabled kubernetes auth method at: kubernetes/

vault write auth/kubernetes/config \
    issuer="https://kubernetes.default.svc.cluster.local" \
    token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
    kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

Success! Data written to: auth/kubernetes/config
```

- Create a policy & role for your app in Vault

```sh
vault policy write internal-app - <<EOF
path "secret/data/db-pass" {
  capabilities = ["read"]
}
EOF

vault write auth/kubernetes/role/database \
    bound_service_account_names=webapp-sa \
    bound_service_account_namespaces=default \
    policies=internal-app \
    ttl=20m
```

## Create a vault secret

```sh
kubectl -n vault-server exec -it vault-server-0 -- /bin/sh

Enable KV engine
Put the secret
```

```sh
kubectl create sa webapp-sa

kubectl apply -f sampleapp/.
```