SERVICE ?= frontend
TAG ?= latest
ENV ?= staging
REGISTRY ?= your-registry

export PATH := $(PWD)/bin:$(PATH)

.PHONY: check-tools lint update-tag push

check-tools:
	@mkdir -p bin
	@if [ ! -x bin/kustomize ]; then \
		echo "Installing kustomize..."; \
		curl -sSL "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash >/dev/null 2>&1; \
		mv kustomize bin/kustomize; \
		chmod +x bin/kustomize; \
	fi
	@if [ ! -x bin/yamllint ]; then \
		echo "Installing yamllint..."; \
		curl -sSL "https://github.com/adrienverge/yamllint/releases/latest/download/yamllint" -o bin/yamllint; \
		chmod +x bin/yamllint; \
	fi
	@if [ ! -x bin/kube-linter ]; then \
		echo "Installing kube-linter..."; \
		OS=$$(uname -s | tr '[:upper:]' '[:lower:]'); \
		ARCH=$$(uname -m); \
		if [ "$$ARCH" = "x86_64" ]; then ARCH=amd64; fi; \
		if [ "$$ARCH" = "aarch64" ]; then ARCH=arm64; fi; \
		curl -sSL "https://github.com/stackrox/kube-linter/releases/latest/download/kube-linter-$$OS-$$ARCH.tar.gz" -o /tmp/kube-linter.tar.gz; \
		tar -xzf /tmp/kube-linter.tar.gz -C /tmp; \
		mv /tmp/kube-linter bin/kube-linter; \
		chmod +x bin/kube-linter; \
		rm -f /tmp/kube-linter.tar.gz; \
	fi

lint: check-tools
	@yamllint apps/ infrastructure/
	@kube-linter lint apps/ infrastructure/

update-tag: check-tools
	@cd apps/overlays/$(ENV)/$(SERVICE) && kustomize edit set image $(SERVICE)=$(REGISTRY)/$(SERVICE):$(TAG)

push:
	@git add .
	@git commit -m "cd: update $(SERVICE) tag to $(TAG)" || true
	@git push origin main
