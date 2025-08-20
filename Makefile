# Self-documenting Makefile
# See https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html

.DEFAULT_GOAL := help

.PHONY: help run generate-images

help: ## Show this help message
	@echo 'Usage:'
	@echo '  make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

run: ## Run the solution
	$(MAKE) setup-git
	$(MAKE) build-docs
	$(MAKE) start

start: ## start the applicaton
	@echo "Starting the application..."
	bundle install
	bundle exec jekyll serve

setup-git: ## sets up git submodules and all that
	git submodule init
	git submodule update
	aio/bin/aio-bless

generate-images: ## Generate required images for the application
	echo "Generating images..."
	# Add your image generation commands here, for example:
	# python scripts/generate_images.py

build-docs: ## lets build the documentation
	@echo "Building documentation..."
	rm -rf docs-tmp/
	rm -rf apps/
	rm -rf _img/
	mkdir -p _site/aio/guides/img
	mkdir -p aio/guides/img
	aio/bin/aio-clone docs-tmp
	mkdir -p apps
	./build-docs.sh || { @echo "Error in build-docs.sh"; exit 1; }
	rm -rf docs-tmp
	