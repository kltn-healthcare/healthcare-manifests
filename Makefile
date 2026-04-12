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

# Kube-linter naming convention
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
	
	# 1. Install Kustomize (Pinned Binary)
	@if [ ! -x bin/kustomize ]; then \
		echo "Installing kustomize $(KUSTOMIZE_VERSION)..."; \
		curl -sSL "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash -s -- $(subst v,,$(KUSTOMIZE_VERSION)) >/dev/null 2>&1; \
		mv kustomize bin/kustomize && chmod +x bin/kustomize; \
	fi

	# 2. Install Yamllint (venv-first)
	@if [ ! -x bin/yamllint ]; then \
		echo "Preparing yamllint $(YAMLLINT_VERSION)..."; \
		if python3 -m venv --help >/dev/null 2>&1; then \
			rm -rf bin/.yamllint-venv; \
			if python3 -m venv bin/.yamllint-venv; then \
				if bin/.yamllint-venv/bin/pip install --no-cache-dir "yamllint==$(subst v,,$(YAMLLINT_VERSION))"; then \
					printf '%s\n' '#!/usr/bin/env sh' > bin/yamllint; \
					printf '%s\n' 'set -eu' >> bin/yamllint; \
					printf '%s\n' 'SCRIPT_DIR=$$(CDPATH= cd -- "$$(dirname -- "$$0")" && pwd)' >> bin/yamllint; \
					printf '%s\n' 'exec "$$SCRIPT_DIR/.yamllint-venv/bin/yamllint" "$$@"' >> bin/yamllint; \
					chmod +x bin/yamllint; \
					echo "Installed yamllint in virtualenv"; \
					exit 0; \
				fi; \
			fi; \
			echo "WARNING: venv-based yamllint install failed, trying fallback..."; \
		fi; \
		if command -v yamllint >/dev/null 2>&1; then \
			ln -sf "$$(command -v yamllint)" bin/yamllint; \
			echo "Linked system yamllint to bin/"; \
		else \
			echo "yamllint not found. Installing via python3 -m pip --user..."; \
			if ! python3 -m pip install --user --upgrade --break-system-packages yamllint==$(subst v,,$(YAMLLINT_VERSION)); then \
				echo "ERROR: Failed to install yamllint with pip (PEP 668 or network issue)."; \
				exit 1; \
			fi; \
			USER_BIN=$$(python3 -c 'import site; print(site.USER_BASE)')/bin; \
			Y_PATH="$$USER_BIN/yamllint"; \
			if [ -x "$$Y_PATH" ]; then \
				ln -sf "$$Y_PATH" bin/yamllint; \
				echo "Successfully installed and linked yamllint!"; \
			else \
				echo "ERROR: pip3 installed nothing or path is wrong."; \
				echo "Current PATH: $(PATH)"; \
				echo "Checking if pip3 is even available:"; \
				python3 -m pip --version || echo "pip3 is NOT installed properly for jenkins user."; \
				exit 1; \
			fi; \
		fi; \
	fi

	# 3. Install Kube-linter (Pinned Binary)
	@if [ ! -x bin/kube-linter ]; then \
		echo "Installing kube-linter $(KUBELINTER_VERSION)..."; \
		TMP_DIR=$$(mktemp -d); \
		ASSET_URL="https://github.com/stackrox/kube-linter/releases/download/$(KUBELINTER_VERSION)/kube-linter-$(OS)$(KUBELINTER_ARCH_SUFFIX).tar.gz"; \
		curl -fsSL "$$ASSET_URL" -o "$$TMP_DIR/kube-linter.tar.gz" && \
		tar -xzf "$$TMP_DIR/kube-linter.tar.gz" -C "$$TMP_DIR" && \
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