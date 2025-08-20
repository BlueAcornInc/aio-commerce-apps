#!/bin/bash

find docs-tmp -type f \( -iname "*.md" -o -iname "*.markdown" \) | while read src; do
  dest="apps/${src#docs-tmp/}"
  mkdir -p "$(dirname "$dest")/docs"
  if [ "$(basename "$src")" = "README.md" ]; then
    final_dest="$(dirname "$dest")/docs/$(basename "$(dirname "$src")").md"
    title="$(basename "$(dirname "$src")" | sed 's/[-_]/ /g' | sed 's/\b\w/\U&/g')"
    echo "---" > "$final_dest"
    echo "title: $title" >> "$final_dest"
    echo "layout: page" >> "$final_dest"
    echo "---" >> "$final_dest"
  else
    final_dest="$(dirname "$dest")/docs/$(basename "$src")"
    title="$(basename "$src" .md | sed 's/[-_]/ /g' | sed 's/\b\w/\U&/g')"
    parent="$(basename "$(dirname "$src")" | sed 's/[-_]/ /g' | sed 's/\b\w/\U&/g')"
    echo "---" > "$final_dest"
    echo "title: $title" >> "$final_dest"
    echo "layout: page" >> "$final_dest"
    echo "parent: $parent" >> "$final_dest"
    echo "---" >> "$final_dest"
  fi
  echo "" >> "$final_dest"
  
  # Process the markdown to update image paths before appending to the target file
  # Use direct paths without _site (Jekyll serves from the root directory)
  cat "$src" | sed -E 's|!\[(.*)\]\(/([^)]+)\)|![\1](/aio/guides/img/\2)|g' | sed -E 's|!\[(.*)\]\(([^/][^)]+)\)|![\1](/aio/guides/\2)|g' >> "$final_dest"
  
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