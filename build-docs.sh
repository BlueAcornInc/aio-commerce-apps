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