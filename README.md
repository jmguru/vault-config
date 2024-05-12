## Introduction
In this document, we will quickly setup a stateful Vault server then install the Vault secrets operator. We will also create an example of implementing the Vault secrets operator. 

## Install Vault
This vault is non-dev, stateful with storage. 

### Apply the manifests
In the root directory of the cloned repository, apply the vault sub-directory. 
```
kubectl apply -f vault/
```

Vault is installed in the `vault` namespace. There's only one replica in the replicaset by default. 

### Generate your Vault keys

```
kubectl exec vault-0 -n vault -- vault operator init -key-shares=1 -key-threshold=1 -format=json > keys.json
```

### Unseal Vault
The file `keys.json` should be sitting in root directory of the cloned repository. Run the unseal script:
```
./unseal.sh
```

## Install Vault secret operator
In the same directly, apply the vault-secrets-operator:
```
kubectl apply -f vault-secrets-operator/
```
The operator pod is contained in the namespace `vault-secrets-operator-system`

## Configure Vault
In this section we will do the following:
- Enable an auth for a new mount for this example.
- Create a new path for kv-v2 (key-value) secrets
- Create a new policy for the path
- Create a role for the kubernetes vault secret operator
- Create a sample secret in the new path

###  Enable new auth for mount
Substitute `PATHNAME-MOUNT` with some something descriptive (e.g.`apps-mount`)
```
vault auth enable -path PATHNAME-MOUNT kubernetes
```

### Write auth for new mount as-mount
Substitute `PATHNAME-MOUNT`
```
vault write auth/PATHNAME-MOUNT/config \
   kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
   disable_iss_validation="true"
```

Note: Disabling issuer validation (iss) if you're getting Error 500 - "* claim "iss" is invalid"


### Enable the path as kv-v2
Substitute `PATHNAME` like `apps`

```
vault secrets enable -path=PATHNAME kv-v2
```

### Create the policy with most capabilities
Substitute `POLICYNAME` and `PATHNAME` with your names.
```
vault policy write POLICYNAME - <<EOF
path "PATHNAME/*" {
    capabilities = ["create", "read", "update", "delete", "list"]
}
EOF
```

### Create role for kubernetes secrets
Substitute `PATHNAME-MOUNT`,`POLICYNAME` and `NAMESPACE`

```
vault write auth/PATHNAME-MOUNT/role/role1 \
   bound_service_account_names=default \
   bound_service_account_namespaces=NAMESPACE \
   policies=POLICYNAME \
   audience=vault \
   ttl=24h
```

### Create a secret
Substitute `PATHNAME`. 
```
vault kv put PATHNAME/config/appserverdata @temp.json
```
temp.json:
```
{
  "BALKYHOST":"127.0.0.1",
  "BALKYPORT":"8090",
  "DBHOST":"dbserver",
  "PORT":"8080"
}
```

## Configure a Vault static secret for Kubernetes
In this section, we'll do the following:
- Create the Vault auth required by the vault static secret
- Create the Vault static secret kubernetes that corresponds to the secret in Vault.

### Apply the manifest of the Vault auth
```
kubectl apply -f k8-secrets-config/as-auth
```

### Apply the manifest of the Vault static secret
```
kubectl apply -f appserverdata-secrets.yaml
```

After applying, you should see a secret called appserverdata in the `default` namespace. 

```
kubectl get secrets -n default

NAME            TYPE     DATA   AGE
appserverdata   Opaque   5      3h31m
```

## Example of using the secret in the k8 node application
See the example of a deployment manifest file in `app-example` directory. The deployment pulls the values from the secret as environment variables using secret key reference. Also you can pull these values from a configmap as well (not shown below)

```
...
   spec:
      containers:
        - name: appserver
          env:
          - name: BALKYHOST
            valueFrom:
              secretKeyRef:
                name: appserverdata
                key: BALKYHOST
          - name: BALKYPORT
            valueFrom:
              secretKeyRef:
                name: appserverdata
                key: BALKYPORT
          - name: DBHOST
            valueFrom:
              secretKeyRef:
                name: appserverdata
                key: DBHOST
          - name: PORT
            valueFrom:
              secretKeyRef:
                name: appserverdata
                key: PORT
...
```
