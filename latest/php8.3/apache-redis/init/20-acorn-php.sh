#!/usr/bin/env bash

set -e


# Check if the wp acorn command is available
if wp acorn &> /dev/null; then
    echo "wp acorn command is available"

    echo "Clearing Acorn and optimize..."
    wp acorn optimize

    # Run wp acorn view:cache command
    echo "Running wp acorn icons:cache..."
     if ! wp acorn icons:cache; then
        echo "Failed to cache icons" >&2
        exit 1
     fi
else
    echo "project is not using Acorn or Acorn is not installed... skipping Acorn commands."
fi
