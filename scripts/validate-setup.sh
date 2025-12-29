#!/bin/bash

# n8n on GCR - Setup Validation Script
# This script validates that all prerequisites are met before deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
ERRORS=0
WARNINGS=0

echo "================================================"
echo "  n8n on Google Cloud Run - Setup Validator"
echo "================================================"
echo ""

# Function to check command existence
check_command() {
    local cmd=$1
    local name=$2
    local required=$3
    
    if command -v $cmd &> /dev/null; then
        echo -e "${GREEN}✓${NC} $name is installed"
        return 0
    else
        if [ "$required" = "true" ]; then
            echo -e "${RED}✗${NC} $name is NOT installed (required)"
            ERRORS=$((ERRORS + 1))
        else
            echo -e "${YELLOW}⚠${NC} $name is NOT installed (optional)"
            WARNINGS=$((WARNINGS + 1))
        fi
        return 1
    fi
}

# Function to check gcloud authentication
check_gcloud_auth() {
    echo ""
    echo -e "${BLUE}Checking gcloud authentication...${NC}"
    
    if gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | grep -q "@"; then
        local account=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -n1)
        echo -e "${GREEN}✓${NC} gcloud is authenticated as: $account"
        return 0
    else
        echo -e "${RED}✗${NC} gcloud is not authenticated"
        echo "  Run: gcloud auth login"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

# Function to check gcloud application default credentials
check_gcloud_adc() {
    echo ""
    echo -e "${BLUE}Checking gcloud application-default credentials...${NC}"
    
    if gcloud auth application-default print-access-token &>/dev/null; then
        echo -e "${GREEN}✓${NC} Application default credentials are configured"
        return 0
    else
        echo -e "${YELLOW}⚠${NC} Application default credentials not configured"
        echo "  Run: gcloud auth application-default login"
        echo "  (Required for Terraform to authenticate)"
        WARNINGS=$((WARNINGS + 1))
        return 1
    fi
}

# Function to check gcloud project
check_gcloud_project() {
    echo ""
    echo -e "${BLUE}Checking Google Cloud project configuration...${NC}"
    
    local project=$(gcloud config get-value project 2>/dev/null)
    if [ -n "$project" ]; then
        echo -e "${GREEN}✓${NC} Active project: $project"
        
        # Check if project exists and is accessible
        if gcloud projects describe "$project" &>/dev/null; then
            echo -e "${GREEN}✓${NC} Project is accessible"
        else
            echo -e "${RED}✗${NC} Project exists but may not be accessible"
            ERRORS=$((ERRORS + 1))
        fi
        return 0
    else
        echo -e "${YELLOW}⚠${NC} No active project configured"
        echo "  Run: gcloud config set project YOUR_PROJECT_ID"
        WARNINGS=$((WARNINGS + 1))
        return 1
    fi
}

# Function to check terraform configuration
check_terraform_config() {
    echo ""
    echo -e "${BLUE}Checking Terraform configuration...${NC}"
    
    if [ -f "terraform/terraform.tfvars" ]; then
        echo -e "${GREEN}✓${NC} terraform.tfvars file exists"
        
        # Check if project ID is set
        if grep -q "gcp_project_id.*=.*\".*\"" terraform/terraform.tfvars 2>/dev/null; then
            local project_id=$(grep "gcp_project_id" terraform/terraform.tfvars | awk -F'=' '{print $2}' | tr -d ' "')
            echo -e "${GREEN}✓${NC} Project ID is configured: $project_id"
        else
            echo -e "${RED}✗${NC} Project ID not set in terraform.tfvars"
            echo "  Edit terraform/terraform.tfvars and set: gcp_project_id = \"your-project-id\""
            ERRORS=$((ERRORS + 1))
        fi
    else
        echo -e "${YELLOW}⚠${NC} terraform.tfvars not found"
        echo "  Copy terraform/terraform.tfvars.example to terraform/terraform.tfvars"
        echo "  Then edit it to set your project ID"
        WARNINGS=$((WARNINGS + 1))
    fi
}

# Function to check Docker (optional)
check_docker_optional() {
    echo ""
    echo -e "${BLUE}Checking Docker (optional - for custom image)...${NC}"
    
    if check_command docker "Docker" "false"; then
        # Check if Docker daemon is running
        if docker info &>/dev/null; then
            echo -e "${GREEN}✓${NC} Docker daemon is running"
        else
            echo -e "${YELLOW}⚠${NC} Docker is installed but daemon is not running"
            echo "  Start Docker Desktop or run: sudo systemctl start docker"
            WARNINGS=$((WARNINGS + 1))
        fi
    else
        echo "  Docker is only needed if using custom image (Option B)"
        echo "  For official image (Option A), Docker is not required"
    fi
}

# Function to check required APIs
check_required_apis() {
    echo ""
    echo -e "${BLUE}Checking required Google Cloud APIs...${NC}"
    
    local project=$(gcloud config get-value project 2>/dev/null)
    if [ -z "$project" ]; then
        echo -e "${YELLOW}⚠${NC} Cannot check APIs - no project configured"
        return 1
    fi
    
    local apis=(
        "run.googleapis.com:Cloud Run"
        "sqladmin.googleapis.com:Cloud SQL Admin"
        "secretmanager.googleapis.com:Secret Manager"
    )
    
    for api_info in "${apis[@]}"; do
        IFS=':' read -r api name <<< "$api_info"
        if gcloud services list --enabled --filter="name:$api" --format="value(name)" 2>/dev/null | grep -q "$api"; then
            echo -e "${GREEN}✓${NC} $name API is enabled"
        else
            echo -e "${YELLOW}⚠${NC} $name API is not enabled"
            echo "  Will be enabled automatically during deployment"
        fi
    done
}

# Main validation flow
echo "1. Checking Required Tools"
echo "-------------------------"
check_command gcloud "gcloud CLI" "true"
check_command terraform "Terraform" "true"

echo ""
echo "2. Checking gcloud Configuration"
echo "--------------------------------"
check_gcloud_auth
check_gcloud_adc
check_gcloud_project

echo ""
echo "3. Checking Terraform Configuration"
echo "-----------------------------------"
check_terraform_config

echo ""
echo "4. Checking Optional Tools"
echo "--------------------------"
check_docker_optional

echo ""
echo "5. Checking Google Cloud APIs"
echo "-----------------------------"
check_required_apis

# Summary
echo ""
echo "================================================"
echo "  Validation Summary"
echo "================================================"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo ""
    echo "You're ready to deploy. Run:"
    echo "  cd terraform"
    echo "  terraform init"
    echo "  terraform plan"
    echo "  terraform apply"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ $WARNINGS warning(s) found${NC}"
    echo ""
    echo "You can proceed with deployment, but review warnings above."
    echo "Some features may not work without addressing warnings."
    exit 0
else
    echo -e "${RED}✗ $ERRORS error(s) found${NC}"
    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}⚠ $WARNINGS warning(s) found${NC}"
    fi
    echo ""
    echo "Please fix the errors above before deploying."
    echo "See QUICKSTART.md for installation instructions."
    exit 1
fi
