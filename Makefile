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

# Kube-linter uses no arch suffix for amd64 and _arm64 for arm64.
ifeq ($(ARCH_FIXED),amd64)
    KUBELINTER_ARCH_SUFFIX :=
else ifeq ($(ARCH_FIXED),arm64)
    KUBELINTER_ARCH_SUFFIX := _arm64
else
    KUBELINTER_ARCH_SUFFIX := _$(ARCH_FIXED)
endif

.PHONY: check-tools lint update-tag push

check-tools:
	@mkdir -p bin
	
	# Install Kustomize (Pinned Version)
	@if [ ! -x bin/kustomize ]; then \
		echo "Installing kustomize $(KUSTOMIZE_VERSION)..."; \
		curl -sSL "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash -s -- $(subst v,,$(KUSTOMIZE_VERSION)) >/dev/null 2>&1; \
		mv kustomize bin/kustomize && chmod +x bin/kustomize; \
	fi

	# Install Yamllint (No Sudo - using pip)
	@if [ ! -x bin/yamllint ]; then \
		echo "Installing yamllint $(YAMLLINT_VERSION)..."; \
		if command -v yamllint >/dev/null 2>&1; then \
			ln -sf "$$(command -v yamllint)" bin/yamllint; \
		else \
			python3 -m pip install --user yamllint==$(YAMLLINT_VERSION) >/dev/null 2>&1 || pip install --user yamllint==$(YAMLLINT_VERSION) >/dev/null 2>&1; \
			if [ -f "$$HOME/.local/bin/yamllint" ]; then \
				ln -sf "$$HOME/.local/bin/yamllint" bin/yamllint; \
			else \
				echo "Searching for yamllint binary..."; \
				YAMLLINT_PATH=$$(find $$HOME/.local -name yamllint -type f | head -n1); \
				if [ -n "$$YAMLLINT_PATH" ]; then ln -sf "$$YAMLLINT_PATH" bin/yamllint; \
				else echo "Warning: yamllint not found. Ensure pip is installed."; exit 1; fi; \
			fi; \
		fi; \
	fi

	# Install Kube-linter (Pinned Version v0.8.3)
	@if [ ! -x bin/kube-linter ]; then \
		echo "Installing kube-linter $(KUBELINTER_VERSION)..."; \
		TMP_DIR=$$(mktemp -d); \
		ASSET_URL="https://github.com/stackrox/kube-linter/releases/download/$(KUBELINTER_VERSION)/kube-linter-$(OS)$(KUBELINTER_ARCH_SUFFIX).tar.gz"; \
		if ! curl -fsSL "$$ASSET_URL" -o "$$TMP_DIR/kube-linter.tar.gz"; then \
			echo "Failed to download kube-linter from $$ASSET_URL"; \
			rm -rf "$$TMP_DIR"; exit 1; \
		fi; \
		tar -xzf "$$TMP_DIR/kube-linter.tar.gz" -C "$$TMP_DIR"; \
		mv "$$TMP_DIR/kube-linter" bin/kube-linter && chmod +x bin/kube-linter; \
		rm -rf "$$TMP_DIR"; \
	fi

lint: check-tools
	@echo "Running linting tools..."
	@bin/yamllint apps/ infrastructure/
	@bin/kube-linter lint apps/ infrastructure/

update-tag: check-tools
	@echo "Updating kustomize image tag to $(TAG)..."
	@cd apps/overlays/$(ENV)/$(SERVICE) && ../../../../bin/kustomize edit set image $(SERVICE)=$(REGISTRY)/$(SERVICE):$(TAG)

push:
	@echo "Pushing manifest changes to Git..."
	@git add .
	@git commit -m "cd: update $(SERVICE) tag to $(TAG)" || true
	@git push origin main