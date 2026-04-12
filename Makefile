# Deployment Variables
SERVICE  ?= frontend
TAG      ?= latest
ENV      ?= staging
REGISTRY ?= your-registry

# Tool Versions
KUSTOMIZE_VERSION   ?= v5.3.0
KUBELINTER_VERSION  ?= v0.8.3
YAMLLINT_VERSION    ?= v1.38.0

# Environment Setup
export PATH := $(PWD)/bin:$(PATH)
OS   := $(shell uname -s | tr '[:upper:]' '[:lower:]')
ARCH := $(shell uname -m)

# Fix Architecture naming for binaries
ifeq ($(ARCH),x86_64)
    ARCH_FIXED := amd64
else ifeq ($(ARCH),aarch64)
    ARCH_FIXED := arm64
else
    ARCH_FIXED := $(ARCH)
endif

.PHONY: check-tools lint update-tag push

check-tools:
	@mkdir -p bin
	
	# Install Kustomize (Pinned Version)
	@if [ ! -x bin/kustomize ]; then \
		echo "Installing kustomize $(KUSTOMIZE_VERSION)..."; \
		curl -sSL "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash -s -- $(subst v,,$(KUSTOMIZE_VERSION)) >/dev/null 2>&1; \
		mv kustomize bin/kustomize; \
		chmod +x bin/kustomize; \
	fi

	# Install Yamllint (Pinned Version)
	@if [ ! -x bin/yamllint ]; then \
		echo "Installing yamllint $(YAMLLINT_VERSION)..."; \
		curl -sSL "https://github.com/adrienverge/yamllint/releases/download/$(YAMLLINT_VERSION)/yamllint" -o bin/yamllint; \
		chmod +x bin/yamllint; \
	fi

	# Install Kube-linter (Pinned Version v0.8.3)
	@if [ ! -x bin/kube-linter ]; then \
		echo "Installing kube-linter $(KUBELINTER_VERSION)..."; \
		TMP_DIR=$$(mktemp -d); \
		ASSET_URL="https://github.com/stackrox/kube-linter/releases/download/$(KUBELINTER_VERSION)/kube-linter-$(OS)-$(ARCH_FIXED).tar.gz"; \
		curl -fsSL "$$ASSET_URL" -o "$$TMP_DIR/kube-linter.tar.gz" || (echo "Failed to download kube-linter" && exit 1); \
		tar -xzf "$$TMP_DIR/kube-linter.tar.gz" -C "$$TMP_DIR"; \
		mv "$$TMP_DIR/kube-linter" bin/kube-linter; \
		chmod +x bin/kube-linter; \
		rm -rf "$$TMP_DIR"; \
	fi

lint: check-tools
	@echo "Running linting tools..."
	@yamllint apps/ infrastructure/
	@kube-linter lint apps/ infrastructure/

update-tag: check-tools
	@echo "Updating kustomize image tag to $(TAG)..."
	@cd apps/overlays/$(ENV)/$(SERVICE) && kustomize edit set image $(SERVICE)=$(REGISTRY)/$(SERVICE):$(TAG)

push:
	@echo "Pushing manifest changes to Git..."
	@git add .
	@git commit -m "cd: update $(SERVICE) tag to $(TAG)" || true
	@git push origin main