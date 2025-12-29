#!/bin/bash

# n8n on GCR - Simple Deployment Wrapper
# This script provides a simplified deployment experience

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "================================================"
echo "  n8n on Google Cloud Run - Quick Deploy"
echo "================================================"
echo ""

# Function to display usage
usage() {
    echo "Usage: $0 [option]"
    echo ""
    echo "Options:"
    echo "  setup       - Run initial setup (validate environment)"
    echo "  deploy      - Deploy with Terraform (official image)"
    echo "  custom      - Deploy with custom Docker image"
    echo "  update      - Update existing deployment"
    echo "  check       - Run health checks"
    echo "  cleanup     - Remove all resources"
    echo "  help        - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 setup      # Validate your environment"
    echo "  $0 deploy     # Deploy n8n"
    echo "  $0 check      # Check deployment health"
    echo ""
    exit 1
}

# Check if we're in the right directory
if [ ! -f "README.md" ] || [ ! -d "terraform" ]; then
    echo -e "${RED}Error: Please run this script from the repository root directory${NC}"
    exit 1
fi

# Parse command
COMMAND=${1:-help}

case $COMMAND in
    setup)
        echo "Running environment validation..."
        echo ""
        ./scripts/validate-setup.sh
        ;;
    
    deploy)
        echo "Deploying n8n with official image (recommended)..."
        echo ""
        
        # Validate first
        if ! ./scripts/validate-setup.sh; then
            echo ""
            echo -e "${RED}Validation failed. Please fix errors before deploying.${NC}"
            exit 1
        fi
        
        echo ""
        echo "Starting deployment..."
        cd terraform
        
        if [ ! -f ".terraform/terraform.tfstate" ]; then
            echo "Initializing Terraform..."
            terraform init
        fi
        
        echo ""
        echo "Planning deployment..."
        terraform plan
        
        echo ""
        read -p "Proceed with deployment? (yes/no): " confirm
        
        if [ "$confirm" = "yes" ]; then
            terraform apply
            
            echo ""
            echo -e "${GREEN}✓ Deployment completed!${NC}"
            echo ""
            
            # Get the URL
            if command -v terraform &> /dev/null; then
                N8N_URL=$(terraform output -raw cloud_run_service_url 2>/dev/null || echo "")
                if [ -n "$N8N_URL" ]; then
                    echo "Your n8n instance is available at:"
                    echo -e "${BLUE}$N8N_URL${NC}"
                    echo ""
                fi
            fi
            
            echo "Run health check with: $0 check"
        else
            echo "Deployment cancelled."
        fi
        ;;
    
    custom)
        echo "Deploying n8n with custom Docker image..."
        echo ""
        
        # Check if Docker is available
        if ! command -v docker &> /dev/null; then
            echo -e "${RED}Error: Docker is required for custom image deployment${NC}"
            echo "Install Docker or use: $0 deploy (for official image)"
            exit 1
        fi
        
        # Validate first
        if ! ./scripts/validate-setup.sh; then
            echo ""
            echo -e "${RED}Validation failed. Please fix errors before deploying.${NC}"
            exit 1
        fi
        
        echo ""
        echo "Building and deploying custom image..."
        ./deploy.sh
        
        echo ""
        echo -e "${GREEN}✓ Custom image deployment completed!${NC}"
        echo ""
        echo "Run health check with: $0 check"
        ;;
    
    update)
        echo "Updating n8n deployment..."
        echo ""
        
        if [ ! -d "terraform/.terraform" ]; then
            echo -e "${RED}Error: Terraform not initialized${NC}"
            echo "Run: $0 deploy first"
            exit 1
        fi
        
        cd terraform
        terraform apply
        
        echo ""
        echo -e "${GREEN}✓ Update completed!${NC}"
        ;;
    
    check)
        echo "Running health checks..."
        echo ""
        ./scripts/health-check.sh
        ;;
    
    cleanup)
        ./scripts/cleanup.sh
        ;;
    
    help|--help|-h)
        usage
        ;;
    
    *)
        echo -e "${RED}Error: Unknown command '$COMMAND'${NC}"
        echo ""
        usage
        ;;
esac
