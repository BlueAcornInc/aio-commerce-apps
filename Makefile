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
	@echo "Generating images..."
	# Add your image generation commands here, for example:
	# python scripts/generate_images.py

build-docs: ## lets build the documentation
	@echo "Building documentation..."
	rm -rf docs-tmp/
	rm -rf apps/
	aio/bin/aio-clone docs-tmp
	mkdir -p apps
	find docs-tmp -type f \( -iname '*.md' -o -iname '*.markdown' \) | while read src; do \
		dest="apps/$${src#docs-tmp/}"; \
		mkdir -p "$$(dirname "$$dest")/docs"; \
		if [ "$$(basename "$$src")" = "README.md" ]; then \
			final_dest="$$(dirname "$$dest")/docs/$$(basename "$$(dirname "$$src")").md"; \
			title="$$(basename "$$(dirname "$$src")" | sed 's/[-_]/ /g' | sed 's/\b\w/\U&/g')"; \
			echo "---" > "$$final_dest"; \
			echo "title: $$title" >> "$$final_dest"; \
			echo "layout: page" >> "$$final_dest"; \
			echo "---" >> "$$final_dest"; \
		else \
			final_dest="$$(dirname "$$dest")/docs/$$(basename "$$src")"; \
			title="$$(basename "$$src" .md | sed 's/[-_]/ /g' | sed 's/\b\w/\U&/g')"; \
			parent="$$(basename "$$(dirname "$$src")" | sed 's/[-_]/ /g' | sed 's/\b\w/\U&/g')"; \
			echo "---" > "$$final_dest"; \
			echo "title: $$title" >> "$$final_dest"; \
			echo "layout: page" >> "$$final_dest"; \
			echo "parent: $$parent" >> "$$final_dest"; \
			echo "---" >> "$$final_dest"; \
		fi; \
		echo "" >> "$$final_dest"; \
		cat "$$src" >> "$$final_dest"; \
	done
	rm -rf docs-tmp
