# n8n on Google Cloud Run - Quick Start Guide

This guide will help you deploy n8n on Google Cloud Run in the simplest way possible.

## Prerequisites

Before starting, ensure you have:

1. **A Google Cloud Account** with billing enabled
2. **gcloud CLI** installed and configured
3. **Terraform** installed (v1.0 or higher)
4. **Docker** installed (only if using custom image - Option B)

### Installing Prerequisites

#### Install gcloud CLI

**macOS:**
```bash
brew install --cask google-cloud-sdk
```

**Linux:**
```bash
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
```

**Windows:**
Download from: https://cloud.google.com/sdk/docs/install

**After installation, initialize:**
```bash
gcloud init
gcloud auth login
gcloud auth application-default login
```

#### Install Terraform

**macOS:**
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

**Linux:**
```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

**Windows:**
Download from: https://www.terraform.io/downloads

**Verify installation:**
```bash
terraform --version
```

#### Install Docker (Optional - only for custom image)

**macOS:**
```bash
brew install --cask docker
```

**Linux:**
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

**Windows:**
Download from: https://www.docker.com/products/docker-desktop

## Quick Deployment Steps

### Step 1: Validate Your Environment

Run the validation script to check if all prerequisites are met:

```bash
./scripts/validate-setup.sh
```

This will check for:
- gcloud CLI installation and authentication
- Terraform installation
- Docker installation (if using custom image)
- Google Cloud project configuration

### Step 2: Configure Your Deployment

Create a `terraform.tfvars` file in the `terraform/` directory:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set your project ID (minimum required):

```hcl
gcp_project_id = "your-project-id"
```

**Optional configurations:**
```hcl
# Change region (default: us-west2)
gcp_region = "us-east1"

# Use custom Docker image instead of official (default: false)
use_custom_image = false

# Adjust resources if needed
cloud_run_cpu = "2"
cloud_run_memory = "2Gi"
```

### Step 3: Deploy with Terraform

**Option A: Using Official Image (Recommended - Simpler)**

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

**Option B: Using Custom Image (Advanced)**

```bash
# First build and push the custom image
cd ..  # Back to root directory
./deploy.sh
```

The deploy script will:
1. Build your custom Docker image
2. Push it to Google Artifact Registry
3. Deploy all infrastructure via Terraform

### Step 4: Access Your n8n Instance

After deployment completes, Terraform will output the URL:

```
cloud_run_service_url = "https://n8n-xxxxx-xx.run.app"
```

Open this URL in your browser to access your n8n instance!

### Step 5: Initial n8n Setup

1. **Create your first user account** - You'll be prompted to create an owner account
2. **Set up workflows** - Start creating your automation workflows
3. **Configure OAuth** (optional) - See below if you need to connect to Google services

## Connecting to Google Services (Optional)

If you want to use Google Sheets, Drive, or other Google services in your workflows:

### Enable APIs

```bash
# Enable required Google APIs
gcloud services enable sheets.googleapis.com
gcloud services enable drive.googleapis.com
# Add other APIs as needed
```

### Configure OAuth Consent Screen

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Navigate to **APIs & Services** → **OAuth consent screen**
3. Choose **External** user type
4. Fill in required information:
   - App name: "n8n Workflows"
   - User support email: your email
   - Developer contact: your email
5. Add scopes:
   - `https://www.googleapis.com/auth/drive.file`
   - `https://www.googleapis.com/auth/spreadsheets`
6. Add test users (your email) if using External type

### Create OAuth Credentials

1. Go to **APIs & Services** → **Credentials**
2. Click **CREATE CREDENTIALS** → **OAuth client ID**
3. Select **Web application**
4. Add authorized origins:
   ```
   https://n8n-xxxxx-xx.run.app
   ```
5. Add redirect URI:
   ```
   https://n8n-xxxxx-xx.run.app/rest/oauth2-credential/callback
   ```
6. Copy the Client ID and Client Secret

### Add Credentials in n8n

1. Open your n8n instance
2. Go to **Credentials** → **Add Credential**
3. Search for "Google" and select the service you need
4. Choose **OAuth2** authentication
5. Paste your Client ID and Client Secret
6. Complete the OAuth flow

## Verification & Health Check

Run the health check script to verify your deployment:

```bash
./scripts/health-check.sh
```

This will check:
- Cloud Run service status
- Database connectivity
- Service accessibility
- Configuration correctness

## Cost Estimates

Expected monthly costs (assuming light to moderate usage):

- **Cloud SQL (db-f1-micro)**: ~$8-10/month
- **Cloud Run**: $0-2/month (mostly covered by free tier)
- **Secret Manager**: $0 (free tier)
- **Artifact Registry**: $0-1/month

**Total: ~$8-13/month** for a fully managed n8n instance!

With `min_instances=0`, the service scales to zero when idle, minimizing costs.

## Troubleshooting

### Service won't start

Check the logs:
```bash
gcloud run services logs read n8n --region=<your-region> --limit=50
```

Common issues:
- Database connection timeout → Increase startup probe timeout
- Port mismatch → Ensure `cloud_run_container_port` is 5678
- Memory issues → Increase memory allocation

### Can't access the URL

1. Check if the service is deployed:
   ```bash
   gcloud run services list --region=<your-region>
   ```

2. Verify IAM permissions allow public access:
   ```bash
   gcloud run services get-iam-policy n8n --region=<your-region>
   ```

3. Should see `allUsers` with `roles/run.invoker`

### OAuth redirect errors

- Ensure `N8N_HOST`, `WEBHOOK_URL`, and `N8N_EDITOR_BASE_URL` are set correctly
- Verify redirect URIs in Google Cloud Console match exactly
- Check that the service URL is accessible

### Database issues

- Verify Cloud SQL instance is running
- Check service account has `cloudsql.client` role
- Confirm database credentials in Secret Manager

## Updating n8n

To update to the latest version:

**Option A (Official Image):**
```bash
cd terraform
terraform apply -var="use_custom_image=false"
```

**Option B (Custom Image):**
```bash
./deploy.sh
```

## Cleanup / Teardown

To completely remove all resources and stop incurring costs:

```bash
cd terraform
terraform destroy
```

This will delete:
- Cloud Run service
- Cloud SQL database (and all data)
- Secrets
- Service accounts
- Artifact Registry (if using custom image)

**Warning:** This is irreversible! Make sure to backup any important workflows or data first.

## Next Steps

- Read the full [README.md](README.md) for detailed explanations
- Check out [n8n documentation](https://docs.n8n.io/) for workflow tutorials
- Join the [n8n community](https://community.n8n.io/) for help and ideas

## Getting Help

- **Issues with this repository**: Open an issue on GitHub
- **n8n questions**: Visit [n8n community forums](https://community.n8n.io/)
- **Google Cloud issues**: Check [GCP documentation](https://cloud.google.com/docs)

---

Happy automating! 🚀
