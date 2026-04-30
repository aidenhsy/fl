#!/bin/bash
set -e

REPOS=(
  "fl-api:git@github.com:aidenhsy/fl-api.git"
  "fl-client-ios:git@github.com:aidenhsy/fl-client-ios.git"
  "fl-seller-ios:git@github.com:aidenhsy/fl-seller-ios.git"
)

for entry in "${REPOS[@]}"; do
  dir="${entry%%:*}"
  url="${entry#*:}"

  if [ -d "$dir/.git" ]; then
    echo "Pulling $dir..."
    git -C "$dir" pull
  else
    echo "Cloning $dir..."
    git clone "$url" "$dir"
  fi
done

echo "Done."
