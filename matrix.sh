#!/usr/bin/env bash

set -Eeuo pipefail

# Variables
JSON_FILE="versions.json"
BASE_DOCKER_TAG="inrage/docker-wordpress"

# Fetch the phpVersions and variants from the JSON file
php_versions=$(jq -r '.latest.phpVersions[]' $JSON_FILE)
variants=$(jq -r '.latest.variants[]' $JSON_FILE)

# Initialize the output JSON string
matrix_json="{ \"include\": ["

# For each PHP version...
for version in $php_versions; do
  # For each variant...
  for variant in $variants; do
    # Build the Dockerfile path
    dockerfile_path="latest/php${version}/${variant}/Dockerfile"

    # Construct the Docker tag
    if [[ $variant == "apache" ]]; then
      docker_tag="${BASE_DOCKER_TAG}:${version}"
    else
      docker_tag_variant=${variant#apache-}  # Remove the "apache-" prefix if it exists
      docker_tag="${BASE_DOCKER_TAG}:${version}-${docker_tag_variant}"
    fi

    # Append to the JSON string
    matrix_json+=" {\"dockerfile\": \"${dockerfile_path}\", \"tag\": \"${docker_tag}\"},"
  done
done

# Remove the trailing comma and close the JSON string
matrix_json=${matrix_json%,}
matrix_json+=" ] }"

# Display the JSON
echo $matrix_json
