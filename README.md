# Demo: Automating secret rotation in Kubernetes

[![built with nix](https://builtwithnix.org/badge.svg)](https://builtwithnix.org)

- Event: [Open Source Summit North America 2023](https://ossna2023.sched.com/event/1K5FE)
- Date: 2023-05-12
- [Slides](https://slides.sagikazarmark.hu/2023-05-12-automate-secret-rotation-in-kubernetes/)

This repository contains minimal code for demonstrating how [External Secrets](https://external-secrets.io/) + [Reloader](https://github.com/stakater/Reloader) and [Bank-Vaults](https://bank-vaults.dev) work.

## Prerequisites

- Ability to setup a Kubernetes cluster (eg. using [KinD](https://kind.sigs.k8s.io/))
- kubectl
- kubectl [view-secret plugin](https://github.com/elsesiy/kubectl-view-secret)
- kustomize
- [Helm](https://helm.sh/)
- [vault CLI](https://developer.hashicorp.com/vault/downloads)

Make sure the following repositories are added to Helm (and up-to-date):

```shell
helm repo add banzaicloud-stable https://kubernetes-charts.banzaicloud.com

helm repo add external-secrets https://charts.external-secrets.io

helm repo add stakater https://stakater.github.io/stakater-charts

helm repo update
```

## Preparations

Set up a new Kubernetes cluster using the tools of your choice.

This guide uses [KinD](https://kind.sigs.k8s.io/):

```shell
kind create cluster
```

_The rest of the instructions assume your current context is set to your demo cluster._

Install the [Vault operator](https://bank-vaults.dev/docs/operator/):

```shell
helm upgrade --install --wait --namespace vault-system --create-namespace vault-operator banzaicloud-stable/vault-operator
```

Install the [mutating webhook](https://bank-vaults.dev/docs/mutating-webhook/):

```shell
helm upgrade --install --wait --namespace vault-system --create-namespace vault-secrets-webhook banzaicloud-stable/vault-secrets-webhook
```

Install a new Vault instance:

```shell
kustomize build deploy/vault | kubectl apply -f -

sleep 2
kubectl -n vault wait pods vault-0 --for condition=Ready --timeout=120s # wait for Vault to become ready
```

Set the Vault token from the Kubernetes secret:

```shell
export VAULT_TOKEN=$(kubectl -n vault get secrets vault-unseal-keys -o jsonpath={.data.vault-root} | base64 --decode)
```

Tell the CLI where Vault is listening _(optional: this should be the default)_:

```shell
export VAULT_ADDR=http://127.0.0.1:8200
```

Port forward to the Vault service:

```shell
kubectl -n vault port-forward service/vault 8200 1>/dev/null &
```

Check access to Vault:

```shell
vault kv get secret/foo/bar
```

Alternatively, open the UI (and login with the root token):

```shell
open $VAULT_ADDR
```

Install [External Secrets Operator](https://external-secrets.io/latest/introduction/getting-started/):

```shell
helm upgrade --install --wait --namespace external-secrets --create-namespace --set installCRDs=true external-secrets external-secrets/external-secrets
```

Install [Reloader](https://github.com/stakater/Reloader#deploying-to-kubernetes):

```shell
helm upgrade --install --wait --namespace reloader --create-namespace reloader stakater/reloader
```

## Demo

Deploy the demo application:

```shell
kustomize build deploy/demo | kubectl apply -f -

kubectl wait deploy http-echo --for condition=Available=true --timeout=60s # wait for the application to become ready
```

(The above command also configures ESO to use Vault as a [secret store](https://external-secrets.io/v0.8.1/provider/hashicorp-vault/))

### Demo #1

Notice how a secret called `foobar` is created:

```shell
kubectl get secret
```

Expected output:

```
NAME     TYPE     DATA   AGE
foobar   Opaque   1      6s
```

Check the content of the secret:

```shell
kubectl view-secret foobar -a
```

Expected output:

```
hello=World
```

Port forward to the demo service:

```shell
kubectl port-forward service/http-echo 8080 1>/dev/null &
```

Look at the response from the app:

```shell
curl localhost:8080/hello
```

Expected output:

```
Hello World!
```

Change the secret value in Vault to `everyone`:

```shell
vault kv put secret/foo/bar hello=everyone
```

Notice that the content of the secret changed...

```shell
kubectl view-secret foobar -a
```

Expected output:

```
hello=everyone
```

...but the response from the app is still the same:

```shell
curl localhost:8080/hello
```

Expected output:

```
Hello World!
```

Restart the demo app:

```shell
kubectl rollout restart deploy http-echo
```

_(You have to restart the port forward at this point):_

```shell
kill %2
wait %2
kubectl port-forward service/http-echo 8080 1>/dev/null &
```

The app should now return a different response:

```shell
curl localhost:8080/hello
```

Expected output:

```
Hello everyone!
```

Tell Reloader to start watching the deployment for secret changes:

```shell
kubectl annotate deploy http-echo reloader.stakater.com/auto="true"
```

Change the secret value in the store again to `Open Source Summit`:

```shell
vault kv put secret/foo/bar hello="Open Source Summit"
```

Notice that the content of the secret changed again...

```shell
kubectl view-secret foobar -a
```

Expected output:

```
hello=Open Source Summit
```

_(You have to restart the port forward at this point):_

```shell
kill %2
wait %2
kubectl port-forward service/http-echo 8080 1>/dev/null &
```

...and the response from the app changed as well:

```shell
curl localhost:8080/hello
```

Expected output:

```
Hello Open Source Summit!
```

### Demo #2

Look at the Pod (and notice that no mutation happened):

```shell
kubectl get pods -o yaml
```

Look at the value of `HELLO_AGAIN` environment variable:

```shell
curl localhost:8080/env/HELLO_AGAIN
```

Expected output:
```
vault:secret/data/foo/bar#hello
```

Enable mutation to inject secret values:

```shell
kubectl patch deploy http-echo --type=json -p='[{"op":"remove","path":"/spec/template/metadata/annotations/vault.security.banzaicloud.io~1mutate"}]'

kubectl rollout status deploy http-echo --timeout=60s # wait for the rollout to finish
```

_(You have to restart the port forward at this point):_

```shell
kill %2
wait %2
kubectl port-forward service/http-echo 8080 1>/dev/null &
```

Look at the Pod (and notice a number of mutations: init container, volumes and mounts, entrypoint (command) changed):

```shell
kubectl get pods -o yaml
```

Look at the environment variable values again:

```shell
curl localhost:8080/env/HELLO_AGAIN
```

Expected output:
```
Open Source Summit
```

# Cleanup

Kill background jobs:

```shell
kill %2 # demo app port-forward
kill %1 # vault port-forward
```

Tear down the Kubernetes cluster:

```shell
kind delete cluster
```
