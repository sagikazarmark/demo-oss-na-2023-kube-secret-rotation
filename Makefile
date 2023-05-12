# A Self-Documenting Makefile: http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html

.PHONY: up
up: ## Start a Kind cluster
	kind create cluster

.PHONY: down
down: ## Destroy the Kind cluster
	kind delete cluster

.PHONY: setup-helm
setup-helm: ## Set up Helm repositories
	helm repo add banzaicloud-stable https://kubernetes-charts.banzaicloud.com
	helm repo add external-secrets https://charts.external-secrets.io
	helm repo add stakater https://stakater.github.io/stakater-charts
	helm repo update

.PHONY: prep
prep: ## Prepare the cluster by installing all prerequisites
	helm upgrade --install --wait --namespace vault-system --create-namespace vault-operator banzaicloud-stable/vault-operator
	helm upgrade --install --wait --namespace vault-system --create-namespace vault-secrets-webhook banzaicloud-stable/vault-secrets-webhook
	kustomize build deploy/vault | kubectl apply -f -
	sleep 2
	kubectl -n vault wait pods vault-0 --for condition=Ready --timeout=120s # wait for Vault to become ready
	helm upgrade --install --wait --namespace external-secrets --create-namespace --set installCRDs=true external-secrets external-secrets/external-secrets
	helm upgrade --install --wait --namespace reloader --create-namespace reloader stakater/reloader

.PHONY: deploy
deploy: ## Deploy the demo application
	kustomize build deploy/demo | kubectl apply -f -
	kubectl wait deploy http-echo --for condition=Available=true --timeout=60s # wait for the application to become ready

.PHONY: vault-forward
vault-forward: ## Port forward to the Vault service
	kubectl -n vault port-forward service/vault 8200 1>/dev/null

.PHONY: demo-forward
demo-forward: ## Port forward to the demo service
	kubectl port-forward service/http-echo 8080 1>/dev/null

.PHONY: demo-restart
demo-restart: ## Restart the demo service
	kubectl rollout restart deploy http-echo

.PHONY: help
.DEFAULT_GOAL := help
help:
	@grep -h -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
