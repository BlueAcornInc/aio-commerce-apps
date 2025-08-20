#!/bin/bash

# Check if docs-tmp directory exists
if [ ! -d "docs-tmp" ]; then
  echo "Error: docs-tmp directory doesn't exist!"
  exit 1
fi

find docs-tmp -type f \( -iname "*.md" -o -iname "*.markdown" \) | while read src; do
  dest="apps/${src#docs-tmp/}"
  mkdir -p "$(dirname "$dest")/docs"
  if [ "$(basename "$src")" = "README.md" ]; then
    final_dest="$(dirname "$dest")/docs/$(basename "$(dirname "$src")").md"
    title="$(basename "$(dirname "$src")" | sed 's/[-_]/ /g' | sed 's/\b\w/\U&/g')"
    parent=""
  else
    final_dest="$(dirname "$dest")/docs/$(basename "$src")"
    title="$(basename "$src" .md | sed 's/[-_]/ /g' | sed 's/\b\w/\U&/g')"
    parent="$(basename "$(dirname "$src")" | sed 's/[-_]/ /g' | sed 's/\b\w/\U&/g')"
    parent="parent: $parent"
  fi
  
  # Create new frontmatter - start fresh each time
  echo "---" > "$final_dest"
  echo "title: $title" >> "$final_dest"
  echo "layout: page" >> "$final_dest"
  if [ -n "$parent" ]; then
    echo "$parent" >> "$final_dest"
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
        sed -E 's|!\[(.*)\]\(/([^)]+)\)|![\1](/aio/guides/img/\2)|g' | \
        sed -E 's|!\[(.*)\]\(([^/][^)]+)\)|![\1](/aio/guides/\2)|g' >> "$final_dest"
    else
      # No valid frontmatter found - close our frontmatter and copy all content
      echo "---" >> "$final_dest"
      echo "" >> "$final_dest"
      
      # Skip the first line if it's a --- and copy the rest
      if head -1 "$src" | grep -q "^---$"; then
        sed -n '2,$p' "$src" | \
          sed -E 's|!\[(.*)\]\(/([^)]+)\)|![\1](/aio/guides/img/\2)|g' | \
          sed -E 's|!\[(.*)\]\(([^/][^)]+)\)|![\1](/aio/guides/\2)|g' >> "$final_dest"
      else
        cat "$src" | \
          sed -E 's|!\[(.*)\]\(/([^)]+)\)|![\1](/aio/guides/img/\2)|g' | \
          sed -E 's|!\[(.*)\]\(([^/][^)]+)\)|![\1](/aio/guides/\2)|g' >> "$final_dest"
      fi
    fi
  else
    # No frontmatter - close our frontmatter and copy all content
    echo "---" >> "$final_dest"
    echo "" >> "$final_dest"
    
    cat "$src" | \
      sed -E 's|!\[(.*)\]\(/([^)]+)\)|![\1](/aio/guides/img/\2)|g' | \
      sed -E 's|!\[(.*)\]\(([^/][^)]+)\)|![\1](/aio/guides/\2)|g' >> "$final_dest"
  fi
  
  # Extract image references and copy them to the right place
  grep -oE "!\[[^\]]*\]\(([^)]+)\)" "$src" | sed -E "s/.*\(([^)]+)\).*/\1/" | while read -r img_url; do
    if echo "$img_url" | grep -qE "^https?://"; then
      # Handle remote URLs
      img_name="$(basename "$img_url")"
      img_dest="_site/aio/guides/img/$img_name"
      mkdir -p "_site/aio/guides/img"
      if [ ! -f "$img_dest" ]; then
        curl -sSL "$img_url" -o "$img_dest"
      fi
      # Also copy to the Jekyll source directory
      mkdir -p "aio/guides/img"
      cp "$img_dest" "aio/guides/img/$img_name" 2>/dev/null || true
    elif echo "$img_url" | grep -qE "^/"; then
      # Handle absolute paths (starting with /)
      img_name="$(basename "$img_url")"
      img_dest="_site/aio/guides/img/$img_name"
      mkdir -p "_site/aio/guides/img"
      # Search for the image in docs-tmp directory
      find docs-tmp -name "$img_name" -type f -print | xargs -I{} cp {} "$img_dest" 2>/dev/null || true
      # If not found, create a placeholder
      if [ ! -f "$img_dest" ]; then
        convert -size 200x100 xc:white -font Arial -pointsize 16 -fill black -draw "text 20,50 'Image not found: $img_url'" "$img_dest" 2>/dev/null || echo "Image not found: $img_url" > "$img_dest.missing.txt"
        echo "Warning: Image not found: $img_url" >&2
      fi
      # Also copy to the Jekyll source directory
      mkdir -p "aio/guides/img"
      cp "$img_dest" "aio/guides/img/$img_name" 2>/dev/null || true
    else
      # Handle relative paths
      img_name="$(basename "$img_url")"
      img_dest="_site/aio/guides/img/$img_name"
      mkdir -p "_site/aio/guides/img"
      # Try to find and copy the image relative to the original source file
      src_dir="$(dirname "$src")"
      if [ -f "$src_dir/$img_url" ]; then
        cp "$src_dir/$img_url" "$img_dest"
      elif [ -f "$src_dir/img/$img_name" ]; then
        cp "$src_dir/img/$img_name" "$img_dest"
      else
        find docs-tmp -name "$img_name" -type f -print | xargs -I{} cp {} "$img_dest" 2>/dev/null || true
        if [ ! -f "$img_dest" ]; then
          convert -size 200x100 xc:white -font Arial -pointsize 16 -fill black -draw "text 20,50 'Image not found: $img_url'" "$img_dest" 2>/dev/null || echo "Image not found: $img_url" > "$img_dest.missing.txt"
          echo "Warning: Image not found: $img_url" >&2
        fi
      fi
      # Also copy to the Jekyll source directory
      mkdir -p "aio/guides/img"
      cp "$img_dest" "aio/guides/img/$img_name" 2>/dev/null || true
    fi
  done
done

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