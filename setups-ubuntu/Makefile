SHELL := /usr/bin/env bash

.DEFAULT_GOAL := help

.PHONY: help docker-wsl zsh

help: ## Show available commands
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make <target>\n\nTargets:\n"} /^[a-zA-Z0-9_-]+:.*##/ {printf "  %-14s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

docker-wsl: ## Install and configure Docker on WSL
	./setup-docker-wsl.sh

zsh: ## Install and configure Zsh, Oh My Zsh, plugins, theme, and Git aliases
	./setup-zsh.sh
