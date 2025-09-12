#!/bin/bash

echo "Validating Kubernetes Manifests..."

# Find all YAML files and validate them
find k8s-manifests -name "*.yaml" | while read file; do
    echo "Validating: $file"
    kubectl apply --dry-run=client -f "$file" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "  ✓ Valid"
    else
        echo "  ✗ Invalid - Check syntax"
        kubectl apply --dry-run=client -f "$file"
    fi
done