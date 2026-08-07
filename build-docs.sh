#!/bin/bash

# Check if docs-tmp directory exists
if [ ! -d "docs-tmp" ]; then
  echo "Error: docs-tmp directory doesn't exist!"
  exit 1
fi

# Turn a path component into a nav label: "store-locator" -> "Store Locator".
# awk rather than sed: `\b\w/\U&` is a GNU extension that silently does nothing
# on BSD sed, so titles came out lower-cased on macOS and capitalised in CI.
titlecase() {
  echo "$1" | tr '_-' '  ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1'
}

# Display names that titlecase cannot derive: repo and file names carry no word
# boundaries ("storelocator") or are shouted ("EDS.md", "DEVELOPMENT.md").
# Anything not listed falls through to titlecase.
label_for() {
  case "$1" in
    storelocator)   echo "Store Locator" ;;
    shipstation)    echo "ShipStation" ;;
    bazaarvoice)    echo "Bazaarvoice" ;;
    yotpo)          echo "Yotpo" ;;
    stripe)         echo "Stripe" ;;
    guides)         echo "Guides" ;;
    EDS)            echo "EDS Storefront" ;;
    DEVELOPMENT)    echo "Development" ;;
    CICD)           echo "CI/CD" ;;
    INSTALLATION)   echo "Installation" ;;
    CODE_OF_CONDUCT) echo "Code of Conduct" ;;
    *)              titlecase "$1" ;;
  esac
}

# Reading order within an app. Alphabetical puts "Blocks" before "Install" and
# buries the page most readers actually want. Lower sorts first; anything not
# listed lands in the middle, and a repo can still override by setting
# nav_order in its own front matter (that wins -- see the copy below).
order_for() {
  case "$1" in
    install|INSTALLATION) echo 10 ;;
    configuration)        echo 20 ;;
    EDS)                  echo 30 ;;
    blocks)               echo 40 ;;
    DEVELOPMENT)          echo 60 ;;
    CICD)                 echo 70 ;;
    CODE_OF_CONDUCT)      echo 90 ;;
    *)                    echo 50 ;;
  esac
}

find docs-tmp -type f \( -iname "*.md" -o -iname "*.markdown" \) | while read src; do
  dest="apps/${src#docs-tmp/}"
  mkdir -p "$(dirname "$dest")/docs"
  # Nav hierarchy. Every page belongs under its app; only the app's own README
  # sits at the top level. Without this, a nested block README (which has no
  # parent by virtue of being called README) is promoted to the root, and the
  # sidebar becomes a flat alphabetical list of every app and block mixed
  # together -- with both "store locator" (the block) and "storelocator" (the
  # app) as siblings.
  rel="${src#docs-tmp/}"          # <app>/<subdir>/<file>.md
  app="${rel%%/*}"                # <app>
  subdir="$(dirname "$rel")"      # <app>/<subdir>  (or <app> at the repo root)
  subdir="${subdir#$app}"         # /<subdir>       (or empty)
  subdir="${subdir#/}"            # <subdir>        (or empty)

  app_title="$(label_for "$app")"
  parent=""
  grand_parent=""

  if [ "$(basename "$src")" = "README.md" ]; then
    final_dest="$(dirname "$dest")/docs/$(basename "$(dirname "$src")").md"
    if [ -z "$subdir" ]; then
      # The app's own landing page.
      title="$app_title"
    else
      title="$(label_for "$(basename "$subdir")")"
      up="$(dirname "$subdir")"
      if [ "$up" = "." ]; then
        parent="parent: $app_title"
      else
        parent="parent: $(label_for "$(basename "$up")")"
        grand_parent="grand_parent: $app_title"
      fi
    fi
  else
    final_dest="$(dirname "$dest")/docs/$(basename "$src")"
    title="$(label_for "$(basename "$src" .md)")"
    if [ -z "$subdir" ]; then
      parent="parent: $app_title"
    else
      parent="parent: $(label_for "$(basename "$subdir")")"
      grand_parent="grand_parent: $app_title"
    fi
  fi

  # Create new frontmatter - start fresh each time
  echo "---" > "$final_dest"
  echo "title: $title" >> "$final_dest"
  echo "layout: page" >> "$final_dest"
  if [ -n "$parent" ]; then
    echo "$parent" >> "$final_dest"
  fi
  if [ -n "$grand_parent" ]; then
    echo "$grand_parent" >> "$final_dest"
  fi
  if [ "$(basename "$src")" = "README.md" ]; then
    echo "nav_order: $(order_for "$(basename "$subdir")")" >> "$final_dest"
  else
    echo "nav_order: $(order_for "$(basename "$src" .md)")" >> "$final_dest"
  fi

  # Check if the file has valid frontmatter and extract additional parameters
  if head -1 "$src" | grep -q "^---$"; then
    # Find the second frontmatter marker (must be within first 20 lines to be valid)
    second_marker=$(awk 'NR>1 && NR<=20 && /^---$/ {print NR; exit}' "$src")
    
    if [ -n "$second_marker" ]; then
      # Extract valid key-value pairs from original frontmatter
      sed -n "2,$((second_marker-1))p" "$src" | \
        grep -E "^[a-zA-Z_][a-zA-Z0-9_-]*:[[:space:]]" | \
        grep -v "^title:" | \
        grep -v "^layout:" | \
        grep -v "^parent:" >> "$final_dest"
      
      # Close frontmatter
      echo "---" >> "$final_dest"
      echo "" >> "$final_dest"
      
      # Copy content after the frontmatter
      sed -n "$((second_marker+1)),\$p" "$src" | \
        sed -E 's|!\[(.*)\]\(([^)]+)\)|![\1](/_img/\2)|g' | \
        sed -E 's|/_img/\./|/_img/|g' >> "$final_dest"
    else
      # No valid frontmatter found - close our frontmatter and copy all content
      echo "---" >> "$final_dest"
      echo "" >> "$final_dest"
      
      # Skip the first line if it's a --- and copy the rest
      if head -1 "$src" | grep -q "^---$"; then
        sed -n '2,$p' "$src" | \
          sed -E 's|!\[(.*)\]\(([^)]+)\)|![\1](/_img/\2)|g' | \
          sed -E 's|/_img/\./|/_img/|g' >> "$final_dest"
      else
        cat "$src" | \
          sed -E 's|!\[(.*)\]\(([^)]+)\)|![\1](/_img/\2)|g' | \
          sed -E 's|/_img/\./|/_img/|g' >> "$final_dest"
      fi
    fi
  else
    # No frontmatter - close our frontmatter and copy all content
    echo "---" >> "$final_dest"
    echo "" >> "$final_dest"
    
    cat "$src" | \
      sed -E 's|!\[(.*)\]\(([^)]+)\)|![\1](/_img/\2)|g' | \
      sed -E 's|/_img/\./|/_img/|g' >> "$final_dest"
  fi
  
  # Extract image references and copy them to the right place
  grep -oE "!\[[^\]]*\]\(([^)]+)\)" "$src" | sed -E "s/.*\(([^)]+)\).*/\1/" | while read -r img_url; do
    if echo "$img_url" | grep -qE "^https?://"; then
      # Handle remote URLs
      img_name="$(basename "$img_url")"
      img_dest="_img/$img_name"
      mkdir -p "_img"
      if [ ! -f "$img_dest" ]; then
        echo "Downloading remote image: $img_url"
        curl -sSL "$img_url" -o "$img_dest" || echo "Failed to download: $img_url" >&2
      fi
    elif echo "$img_url" | grep -qE "^/"; then
      # Handle absolute paths (starting with /)
      # Remove leading slash and preserve path structure
      img_path="${img_url#/}"
      img_dest="_img/$img_path"
      mkdir -p "$(dirname "$img_dest")"
      # Search for the image in docs-tmp directory
      img_name="$(basename "$img_url")"
      found_img=$(find docs-tmp -name "$img_name" -type f -print -quit)
      if [ -n "$found_img" ]; then
        echo "Copying image: $found_img -> $img_dest"
        cp "$found_img" "$img_dest"
      else
        echo "Warning: Image not found: $img_url" >&2
        # Create a simple text placeholder
        echo "Image not found: $img_url" > "$img_dest.missing.txt"
      fi
    else
      # Handle relative paths - preserve full path structure
      img_dest="_img/$img_url"
      mkdir -p "$(dirname "$img_dest")"
      # Try to find and copy the image relative to the original source file
      src_dir="$(dirname "$src")"
      
      if [ -f "$src_dir/$img_url" ]; then
        echo "Copying relative image: $src_dir/$img_url -> $img_dest"
        cp "$src_dir/$img_url" "$img_dest"
      else
        # Search for the image anywhere in docs-tmp
        img_name="$(basename "$img_url")"
        found_img=$(find docs-tmp -name "$img_name" -type f -print -quit)
        if [ -n "$found_img" ]; then
          echo "Found image elsewhere: $found_img -> $img_dest"
          cp "$found_img" "$img_dest"
        else
          echo "Warning: Image not found: $img_url (searched in $src_dir)" >&2
          # Create a simple text placeholder
          echo "Image not found: $img_url" > "$img_dest.missing.txt"
        fi
      fi
    fi
  done
done

# Copy all image files from docs-tmp to ensure nothing is missed
echo "Copying all image files from docs-tmp..."
find docs-tmp -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.gif" -o -iname "*.svg" -o -iname "*.webp" \) | while read img_file; do
  # Remove docs-tmp/ and the first directory level, but keep subdirectory structure
  rel_path="${img_file#docs-tmp/}"
  # Remove the first directory component (project name) but keep everything after
  rel_path_no_parent=$(echo "$rel_path" | sed 's|^[^/]*/||')
  img_dest="_img/$rel_path_no_parent"
  mkdir -p "$(dirname "$img_dest")"
  if [ ! -f "$img_dest" ]; then
    echo "Copying additional image: $img_file -> $img_dest"
    cp "$img_file" "$img_dest"
  else
    echo "Image already exists: $img_dest"
  fi
done

# Display final image count for verification
echo "Image processing summary:"
echo "Total images found in docs-tmp: $(find docs-tmp -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.gif" -o -iname "*.svg" -o -iname "*.webp" \) | wc -l)"
echo "Total images copied to _img: $(find _img -type f 2>/dev/null | wc -l || echo "0")"
echo "Images in destination directory:"
ls -la _img/ 2>/dev/null || echo "Directory _img/ does not exist"

# Final validation to ensure proper frontmatter structure
echo "Validating frontmatter in generated files..."
find apps -type f \( -iname "*.md" -o -iname "*.markdown" \) | while read file; do
  # Skip empty files
  if [ ! -s "$file" ]; then
    continue
  fi
  
  # Check if file has proper frontmatter structure
  if ! head -1 "$file" | grep -q "^---$"; then
    echo "No frontmatter found in $file - skipping validation"
    continue
  fi
  
  # Find the closing frontmatter marker within the first 20 lines
  closing_marker=$(awk 'NR>1 && NR<=20 && /^---$/ {print NR; exit}' "$file")
  
  if [ -z "$closing_marker" ]; then
    echo "Fixing incomplete frontmatter in $file"
    
    # Extract title and parent info
    title="$(basename "$file" .md | sed 's/[-_]/ /g' | sed 's/\b\w/\U&/g')"
    parent_dir=$(basename "$(dirname "$file")")
    
    # Create temp file with proper frontmatter
    temp_file=$(mktemp)
    echo "---" > "$temp_file"
    echo "title: $title" >> "$temp_file"
    echo "layout: page" >> "$temp_file"
    if [ "$parent_dir" != "docs" ]; then
      parent="$(echo "$parent_dir" | sed 's/[-_]/ /g' | sed 's/\b\w/\U&/g')"
      echo "parent: $parent" >> "$temp_file"
    fi
    echo "---" >> "$temp_file"
    echo "" >> "$temp_file"
    
    # Copy content, skipping any existing frontmatter
    sed -n '2,$p' "$file" | sed '/^---$/d' >> "$temp_file"
    
    mv "$temp_file" "$file"
    echo "Fixed frontmatter in $file"
  fi
done

echo "Documentation build completed!"