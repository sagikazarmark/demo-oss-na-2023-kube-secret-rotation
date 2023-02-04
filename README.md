# Demo: Automating secret rotation in Kubernetes

- Event: FOSDEM '23 ([Containers devroom](https://fosdem.org/2023/schedule/event/container_kubernetes_secret_rotation/))
- Date: 2023-02-04
- [Slides](https://slides.sagikazarmark.hu/2023-02-04-automating-secret-rotation-in-kubernetes/)

This repository contains minimal code for demonstrating how [External Secrets](https://external-secrets.io/) and [Reloader](https://github.com/stakater/Reloader) work.

## Prerequisites

- Ability to setup a Kubernetes cluster (eg. using [KinD](https://kind.sigs.k8s.io/))
- kubectl
- kubectl [view-secret plugin](https://github.com/elsesiy/kubectl-view-secret)
- Helm

## Preparations

Set up a new Kubernetes cluster using the tools of your choice (this guide uses [KinD](https://kind.sigs.k8s.io/)).

```shell
kind create cluster
```

Install [External Secrets](https://external-secrets.io/latest/introduction/getting-started/):

```shell
helm repo add external-secrets https://charts.external-secrets.io

helm install external-secrets \
   external-secrets/external-secrets \
    -n external-secrets \
    --create-namespace \
    --set installCRDs=true
```

Install [Reloader](https://github.com/stakater/Reloader#deploying-to-kubernetes):

```shell
helm repo add stakater https://stakater.github.io/stakater-charts

helm install reloader \
   stakater/reloader \
    -n reloader \
    --create-namespace
```

## Demo

Inspect and apply the following files:

```
kubectl apply -f deploy/store.yaml
kubectl apply -f deploy/external-secret.yaml
kubectl apply -f deploy/app.yaml
```

Notice how a secret called `foobar` is created:

```shell
kubectl get secret

NAME     TYPE     DATA   AGE
foobar   Opaque   1      6s
```

Check the content of the secret:

```shell
kubectl view-secret foobar -a

hello=World
```

Access the [http-echo2](https://github.com/sagikazarmark/http-echo2) deployment in the cluster (for example using port-forward in a separate shell):

```shell
kubectl port-forward deploy/http-echo 8080
```

Look at the response from the app:

```shell
curl localhost:8080/hello

Hello World!
```

Change the secret value in the store to `everyone`:

```shell
kubectl patch clustersecretstore fake --type=json -p='[{"op": "replace", "path": "/spec/provider/fake/data/0/value", "value": "everyone"}]'
```

Notice that the content of the secret changed...

```shell
kubectl view-secret foobar -a

hello=everyone
```

...but the response from the app is still the same:

```shell
curl localhost:8080/hello

Hello World!
```

Restart the app:

```shell
kubectl rollout restart deploy http-echo
```

(You have to restart the port forward at this point)

The app should now return a different response:

```shell
curl localhost:8080/hello

Hello everyone!
```

Tell Reloader to start watching the deployment for secret changes:

```shell
kubectl annotate deploy http-echo reloader.stakater.com/auto="true"
```

Change the secret value in the store again to `FOSDEM`:

```shell
kubectl patch clustersecretstore fake --type=json -p='[{"op": "replace", "path": "/spec/provider/fake/data/0/value", "value": "FOSDEM"}]'
```

Notice that the content of the secret changed again...

```shell
kubectl view-secret foobar -a

hello=FOSDEM
```

(You have to restart the port forward at this point)

...and the response from the app changed as well:

```shell
curl localhost:8080/hello

Hello FOSDEM!
```

## Cleanup

Tear down the Kubernetes cluster:

```shell
kind delete cluster
```
