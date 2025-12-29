#!/bin/bash

# n8n on GCR - Health Check Script
# This script verifies that your n8n deployment is running correctly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0

echo "================================================"
echo "  n8n on Google Cloud Run - Health Check"
echo "================================================"
echo ""

# Get region and service name from terraform or use defaults
if [ -f "terraform/terraform.tfvars" ]; then
    REGION=$(grep "gcp_region" terraform/terraform.tfvars 2>/dev/null | awk -F'=' '{print $2}' | tr -d ' "' || echo "us-west2")
    SERVICE_NAME=$(grep "cloud_run_service_name" terraform/terraform.tfvars 2>/dev/null | awk -F'=' '{print $2}' | tr -d ' "' || echo "n8n")
else
    REGION="us-west2"
    SERVICE_NAME="n8n"
fi

# Try to get region from gcloud config
if [ -z "$REGION" ] || [ "$REGION" = "us-west2" ]; then
    REGION=$(gcloud config get-value run/region 2>/dev/null || echo "us-west2")
fi

echo "Configuration:"
echo "  Region: $REGION"
echo "  Service: $SERVICE_NAME"
echo ""

# Function to check Cloud Run service status
check_service_status() {
    echo -e "${BLUE}Checking Cloud Run service status...${NC}"
    
    if gcloud run services describe $SERVICE_NAME --region=$REGION &>/dev/null; then
        local status=$(gcloud run services describe $SERVICE_NAME --region=$REGION --format="value(status.conditions[0].status)" 2>/dev/null)
        
        if [ "$status" = "True" ]; then
            echo -e "${GREEN}✓${NC} Cloud Run service is deployed and ready"
            CHECKS_PASSED=$((CHECKS_PASSED + 1))
            return 0
        else
            echo -e "${RED}✗${NC} Cloud Run service exists but is not ready"
            echo "  Status: $status"
            CHECKS_FAILED=$((CHECKS_FAILED + 1))
            return 1
        fi
    else
        echo -e "${RED}✗${NC} Cloud Run service not found"
        echo "  Service '$SERVICE_NAME' does not exist in region '$REGION'"
        echo "  Run terraform apply first"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
        return 1
    fi
}

# Function to get service URL
get_service_url() {
    gcloud run services describe $SERVICE_NAME --region=$REGION --format="value(status.url)" 2>/dev/null
}

# Function to check service accessibility
check_service_accessibility() {
    echo ""
    echo -e "${BLUE}Checking service accessibility...${NC}"
    
    local url=$(get_service_url)
    
    if [ -z "$url" ]; then
        echo -e "${RED}✗${NC} Could not retrieve service URL"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
        return 1
    fi
    
    echo "  Service URL: $url"
    
    # Try to reach the service
    if curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" | grep -q "200\|302\|301"; then
        echo -e "${GREEN}✓${NC} Service is accessible from the internet"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} Service is not accessible"
        echo "  The service may still be starting up"
        echo "  Wait a few minutes and try again"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
        return 1
    fi
}

# Function to check Cloud SQL status
check_database_status() {
    echo ""
    echo -e "${BLUE}Checking Cloud SQL database status...${NC}"
    
    local db_instance="${SERVICE_NAME}-db"
    
    if gcloud sql instances describe $db_instance &>/dev/null; then
        local state=$(gcloud sql instances describe $db_instance --format="value(state)" 2>/dev/null)
        
        if [ "$state" = "RUNNABLE" ]; then
            echo -e "${GREEN}✓${NC} Cloud SQL instance is running"
            CHECKS_PASSED=$((CHECKS_PASSED + 1))
            return 0
        else
            echo -e "${YELLOW}⚠${NC} Cloud SQL instance state: $state"
            if [ "$state" = "PENDING_CREATE" ]; then
                echo "  Database is still being created, this can take several minutes"
            fi
            CHECKS_FAILED=$((CHECKS_FAILED + 1))
            return 1
        fi
    else
        echo -e "${RED}✗${NC} Cloud SQL instance not found"
        echo "  Expected instance name: $db_instance"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
        return 1
    fi
}

# Function to check secrets
check_secrets() {
    echo ""
    echo -e "${BLUE}Checking Secret Manager secrets...${NC}"
    
    local secrets=("${SERVICE_NAME}-db-password" "${SERVICE_NAME}-encryption-key")
    local all_good=true
    
    for secret in "${secrets[@]}"; do
        if gcloud secrets describe $secret &>/dev/null; then
            echo -e "${GREEN}✓${NC} Secret '$secret' exists"
        else
            echo -e "${RED}✗${NC} Secret '$secret' not found"
            all_good=false
        fi
    done
    
    if [ "$all_good" = true ]; then
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
        return 0
    else
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
        return 1
    fi
}

# Function to check service account
check_service_account() {
    echo ""
    echo -e "${BLUE}Checking service account...${NC}"
    
    local project=$(gcloud config get-value project 2>/dev/null)
    local sa_email="n8n-service-account@${project}.iam.gserviceaccount.com"
    
    if gcloud iam service-accounts describe $sa_email &>/dev/null; then
        echo -e "${GREEN}✓${NC} Service account exists: $sa_email"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} Service account not found: $sa_email"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
        return 1
    fi
}

# Function to check recent logs for errors
check_logs() {
    echo ""
    echo -e "${BLUE}Checking recent logs for errors...${NC}"
    
    local error_count=$(gcloud run services logs read $SERVICE_NAME --region=$REGION --limit=100 2>/dev/null | grep -i "error\|fail\|exception" | wc -l)
    
    if [ $error_count -eq 0 ]; then
        echo -e "${GREEN}✓${NC} No errors found in recent logs"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
        return 0
    else
        echo -e "${YELLOW}⚠${NC} Found $error_count potential errors in recent logs"
        echo "  Run this command to view logs:"
        echo "  gcloud run services logs read $SERVICE_NAME --region=$REGION --limit=50"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
        return 0
    fi
}

# Function to display service info
display_service_info() {
    echo ""
    echo "================================================"
    echo "  Service Information"
    echo "================================================"
    
    local url=$(get_service_url)
    echo ""
    echo "n8n URL: $url"
    echo ""
    echo "Useful commands:"
    echo "  View logs:     gcloud run services logs read $SERVICE_NAME --region=$REGION --limit=50"
    echo "  Describe:      gcloud run services describe $SERVICE_NAME --region=$REGION"
    echo "  Update:        cd terraform && terraform apply"
    echo "  Delete:        cd terraform && terraform destroy"
    echo ""
}

# Main health check flow
check_service_status
check_database_status
check_secrets
check_service_account
check_service_accessibility
check_logs

# Summary
echo ""
echo "================================================"
echo "  Health Check Summary"
echo "================================================"
echo ""
echo -e "Checks passed: ${GREEN}$CHECKS_PASSED${NC}"
echo -e "Checks failed: ${RED}$CHECKS_FAILED${NC}"
echo ""

if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All health checks passed!${NC}"
    echo ""
    echo "Your n8n instance is running correctly."
    display_service_info
    exit 0
else
    echo -e "${YELLOW}⚠ Some checks failed${NC}"
    echo ""
    echo "Your deployment may need attention. Review the failed checks above."
    
    if [ $CHECKS_PASSED -gt 0 ]; then
        echo "Some components are working - the service may still be starting up."
        display_service_info
    fi
    
    echo ""
    echo "Troubleshooting tips:"
    echo "  1. Check logs: gcloud run services logs read $SERVICE_NAME --region=$REGION --limit=50"
    echo "  2. Verify all resources were created: cd terraform && terraform plan"
    echo "  3. Check Cloud SQL status in the console"
    echo "  4. Review QUICKSTART.md troubleshooting section"
    
    exit 1
fi
