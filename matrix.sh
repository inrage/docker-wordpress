#!/usr/bin/env bash

set -Eeuo pipefail

# Variables
JSON_FILE="versions.json"
BASE_DOCKER_TAG="inrage/docker-wordpress"

# Fetch the list of available versions
versions=$(jq -r 'keys[]' $JSON_FILE)

# Initialize the output JSON string
matrix_json="{ \"include\": ["

# For each version (e.g., "legacy", "latest")...
for ver in $versions; do

  # Fetch the phpVersions and variants for the current version
  php_versions=$(jq -r ".${ver}.phpVersions[]" $JSON_FILE)
  variants=$(jq -r ".${ver}.variants[]" $JSON_FILE)

  # For each PHP version...
  for version in $php_versions; do
    # For each variant...
    for variant in $variants; do
      # Build the Dockerfile path
      dockerfile_path="${ver}/php${version}/${variant}/Dockerfile"

      # Construct the Docker tag
      if [[ $variant == "apache" ]]; then
        if [[ $ver == "beta" ]]; then
          docker_tag="${BASE_DOCKER_TAG}:beta-${version}"
        else
          docker_tag="${BASE_DOCKER_TAG}:${version}"
        fi
      else
        docker_tag_variant=${variant#apache-}
        if [[ $ver == "beta" ]]; then
          docker_tag="${BASE_DOCKER_TAG}:beta-${version}-${docker_tag_variant}"
        else
          docker_tag="${BASE_DOCKER_TAG}:${version}-${docker_tag_variant}"
        fi
      fi

      # Construct the name
      name="${version}-${variant}"

      # Append to the JSON string
      matrix_json+=" {\"dockerfile\": \"${dockerfile_path}\", \"tag\": \"${docker_tag}\", \"name\": \"${name}\"},"

    done
  done
done

# Remove the trailing comma and close the JSON string
matrix_json=${matrix_json%,}
matrix_json+=" ] }"

# Display the JSON
echo $matrix_json
