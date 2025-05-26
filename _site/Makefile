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

run: ## Run the application
	@echo "Starting the application..."
	bundle install
	bundle exec jekyll serve

generate-images: ## Generate required images for the application
	@echo "Generating images..."
	# Add your image generation commands here, for example:
	# python scripts/generate_images.py
