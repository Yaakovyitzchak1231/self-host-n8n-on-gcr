#!/bin/bash

# n8n on GCR - Cleanup/Teardown Script
# This script helps you safely remove all resources

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "================================================"
echo "  n8n on Google Cloud Run - Cleanup"
echo "================================================"
echo ""
echo -e "${RED}WARNING: This will DELETE all resources!${NC}"
echo ""
echo "This includes:"
echo "  - Cloud Run service"
echo "  - Cloud SQL database (and ALL data)"
echo "  - Secret Manager secrets"
echo "  - Service accounts"
echo "  - Artifact Registry (if using custom image)"
echo ""
echo -e "${YELLOW}This action is IRREVERSIBLE!${NC}"
echo ""

# Ask for confirmation
read -p "Are you sure you want to proceed? (type 'yes' to confirm): " confirm

if [ "$confirm" != "yes" ]; then
    echo ""
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
read -p "Have you backed up any important workflows? (type 'yes' to confirm): " backup_confirm

if [ "$backup_confirm" != "yes" ]; then
    echo ""
    echo "Please backup your workflows first!"
    echo ""
    echo "To export workflows from n8n:"
    echo "  1. Open your n8n instance"
    echo "  2. Go to Workflows"
    echo "  3. Select each workflow and export it"
    echo ""
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "Starting cleanup process..."
echo ""

# Check if terraform directory exists
if [ ! -d "terraform" ]; then
    echo -e "${RED}Error: terraform directory not found${NC}"
    echo "Make sure you're running this from the repository root"
    exit 1
fi

# Use terraform destroy
cd terraform

echo -e "${BLUE}Running terraform destroy...${NC}"
echo ""

if terraform destroy; then
    echo ""
    echo -e "${GREEN}✓ Terraform resources destroyed successfully${NC}"
else
    echo ""
    echo -e "${YELLOW}⚠ Terraform destroy encountered issues${NC}"
    echo ""
    echo "Some resources might not have been deleted."
    echo "You can manually check and delete resources in Google Cloud Console:"
    echo "  - Cloud Run: https://console.cloud.google.com/run"
    echo "  - Cloud SQL: https://console.cloud.google.com/sql"
    echo "  - Secret Manager: https://console.cloud.google.com/security/secret-manager"
    echo "  - IAM: https://console.cloud.google.com/iam-admin/serviceaccounts"
fi

cd ..

echo ""
echo "================================================"
echo "  Cleanup Summary"
echo "================================================"
echo ""
echo "Cleanup process completed."
echo ""
echo "Terraform state files still exist in terraform/ directory."
echo "You can remove them manually if you're sure everything is deleted:"
echo "  rm -rf terraform/.terraform terraform/.terraform.lock.hcl"
echo "  rm -f terraform/terraform.tfstate*"
echo ""
echo "To redeploy later, just run:"
echo "  cd terraform"
echo "  terraform init"
echo "  terraform apply"
echo ""
