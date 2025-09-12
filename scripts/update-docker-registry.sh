#!/bin/bash

# Update Docker Registry Script
# This script helps users update all Docker image references to their own registry

set -e

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Current registry
CURRENT_REGISTRY="jconover"

# Get new registry from user
if [ -z "$1" ]; then
    echo "=========================================="
    echo "🔄 Update Docker Registry References"
    echo "=========================================="
    echo ""
    echo "This script will update all Docker image references from '$CURRENT_REGISTRY' to your registry."
    echo ""
    read -p "Enter your Docker Hub username: " NEW_REGISTRY
    
    if [ -z "$NEW_REGISTRY" ]; then
        echo -e "${RED}❌ No username provided. Exiting.${NC}"
        exit 1
    fi
else
    NEW_REGISTRY="$1"
fi

echo ""
echo -e "${BLUE}📝 Updating registry from '$CURRENT_REGISTRY' to '$NEW_REGISTRY'...${NC}"

# Files to update
FILES=(
    "k8s-manifests/04-microservices/frontend.yaml"
    "k8s-manifests/04-microservices/user-service.yaml"
    "k8s-manifests/04-microservices/product-service.yaml"
    "k8s-manifests/04-microservices/order-service.yaml"
    "k8s-manifests/04-microservices/notification-service.yaml"
    "scripts/build-all-images.sh"
    "scripts/push-all-images.sh"
    "scripts/check-images-status.sh"
)

# Update each file
for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -n "  Updating $file... "
        
        # Create backup
        cp "$file" "$file.bak"
        
        # Update registry references
        sed -i.tmp "s|$CURRENT_REGISTRY/|$NEW_REGISTRY/|g" "$file"
        rm -f "$file.tmp"
        
        echo -e "${GREEN}✅${NC}"
    else
        echo -e "  ${YELLOW}⚠️  $file not found${NC}"
    fi
done

# Update README examples
if [ -f "README.md" ]; then
    echo -n "  Updating README.md examples... "
    cp "README.md" "README.md.bak"
    sed -i.tmp "s|$CURRENT_REGISTRY/|$NEW_REGISTRY/|g" "README.md"
    rm -f "README.md.tmp"
    echo -e "${GREEN}✅${NC}"
fi

# Update documentation
DOC_FILES=(
    "docs/setup-guide.md"
    "docs/post-deployment-guide.md"
    "docs/quick-reference.md"
)

for file in "${DOC_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -n "  Updating $file... "
        cp "$file" "$file.bak"
        sed -i.tmp "s|$CURRENT_REGISTRY/|$NEW_REGISTRY/|g" "$file"
        rm -f "$file.tmp"
        echo -e "${GREEN}✅${NC}"
    fi
done

echo ""
echo -e "${GREEN}✅ Registry update complete!${NC}"
echo ""
echo -e "${BLUE}📋 Summary:${NC}"
echo "  Old registry: $CURRENT_REGISTRY"
echo "  New registry: $NEW_REGISTRY"
echo ""
echo -e "${YELLOW}🔧 Next Steps:${NC}"
echo "1. Login to Docker Hub: docker login"
echo "2. Build images: ./scripts/build-all-images.sh"
echo "3. Push images: ./scripts/push-all-images.sh"
echo "4. Verify images: ./scripts/check-images-status.sh"
echo ""
echo -e "${BLUE}💡 Backup files created with .bak extension${NC}"
echo -e "${BLUE}💡 To revert: mv file.bak file${NC}"

# Verify Docker Hub login
echo ""
echo -n "Checking Docker Hub login... "
if docker info | grep -q "Username"; then
    local username=$(docker info | grep "Username:" | awk '{print $2}')
    if [ "$username" = "$NEW_REGISTRY" ]; then
        echo -e "${GREEN}✅ Logged in as $username${NC}"
    else
        echo -e "${YELLOW}⚠️  Logged in as $username (not $NEW_REGISTRY)${NC}"
        echo -e "${YELLOW}💡 Run: docker logout && docker login${NC}"
    fi
else
    echo -e "${RED}❌ Not logged in${NC}"
    echo -e "${YELLOW}💡 Run: docker login${NC}"
fi
