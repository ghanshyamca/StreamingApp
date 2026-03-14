# StreamingApp — Graded Project: Orchestration and Scaling

---

## 1. Architecture

### Microservices Architecture

```
┌─────────────┐
│   Users     │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────┐
│   AWS Application Load Balancer     │
└──────────────┬──────────────────────┘
               │
               ▼
      ┌────────────────┐
      │   Frontend     │
      │   (React)      │
      └────────┬───────┘
               │
    ┌──────────┴──────────────┬───────────────┬──────────────┐
    ▼                         ▼               ▼              ▼
┌─────────┐             ┌──────────┐    ┌─────────┐   ┌─────────┐
│  Auth   │             │Streaming │    │  Admin  │   │  Chat   │
│ Service │             │ Service  │    │ Service │   │ Service │
│ :3001   │             │  :3002   │    │  :3003  │   │ :3004   │
└────┬────┘             └────┬─────┘    └────┬────┘   └────┬────┘
     │                       │               │             │
     └───────────────┬───────┴───────┬───────┴─────────────┘
                     ▼               ▼
                ┌─────────┐     ┌─────────┐
                │ MongoDB │     │  AWS S3 │
                └─────────┘     └─────────┘
```

---

## STEP 1 — Version Control with Git

### 1.1 Fork the Repository
1. Open browser → go to: **https://github.com/UnpredictablePrashant/StreamingApp**
2. Click the **Fork** button (top-right)
3. Select your GitHub account
4. Wait for GitHub to create your fork at: `https://github.com/YOUR_USERNAME/StreamingApp`

### 1.2 Clone Your Fork Locally
```bash
git clone https://github.com/YOUR_USERNAME/StreamingApp.git
cd StreamingApp
```

### 1.3 Add Upstream Remote (to sync with original)
```bash
git remote add upstream https://github.com/UnpredictablePrashant/StreamingApp.git

# Verify remotes
git remote -v
# Should show:
# origin    https://github.com/YOUR_USERNAME/StreamingApp.git
# upstream  https://github.com/UnpredictablePrashant/StreamingApp.git
```

### 1.4 Sync Your Fork with Upstream (run whenever needed)
```bash
git fetch upstream
git checkout main
git merge upstream/main
git push origin main
```

---

## STEP 2 — Prepare the MERN Application

### 2.1 Review Existing Dockerfiles (already present in repo)

| Service | Dockerfile | Build Context |
|---|---|---|
| Frontend | `frontend/Dockerfile` | `./frontend` |
| Auth Service | `backend/authService/Dockerfile` | `./backend/authService` |
| Streaming | `backend/streamingService/Dockerfile` | `./backend` |
| Admin | `backend/adminService/Dockerfile` | `./backend` |
| Chat | `backend/chatService/Dockerfile` | `./backend` |

**Frontend Dockerfile** uses a two-stage build:
- Stage 1: Node 18 Alpine → `npm install` → `npm run build` (accepts `REACT_APP_*` build args)
- Stage 2: Nginx 1.27 Alpine → serves the built React app on port 80

**Backend Dockerfiles** all use: Node 18 Alpine → `npm install --production` → expose respective port

### 2.2 Set Up .env Files

```bash
# Root .env (used by docker-compose for all services)
cp .env.example .env

# Individual service .env files
cp backend/authService/.env.example      backend/authService/.env
cp backend/streamingService/.env.example backend/streamingService/.env
cp backend/adminService/.env.example     backend/adminService/.env
cp backend/chatService/.env.example      backend/chatService/.env
cp frontend/.env.example                 frontend/.env
```

Edit the root `.env` and fill in your actual values:
```ini
# Shared
CLIENT_URLS=http://localhost:3000
JWT_SECRET=your-strong-secret-here          # Generate: openssl rand -hex 32
MONGO_DB=streamingapp

# AWS
AWS_ACCESS_KEY_ID=AKIAxxxxxxxxxxxxxxxx
AWS_SECRET_ACCESS_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
AWS_REGION=ap-south-1
AWS_S3_BUCKET=your-s3-bucket-name
AWS_CDN_URL=                                # Optional CloudFront URL

# Service Ports
AUTH_PORT=3001
STREAMING_PORT=3002
STREAMING_PUBLIC_URL=http://localhost:3002
ADMIN_PORT=3003
CHAT_PORT=3004

# Frontend build-time values (for local dev)
REACT_APP_AUTH_API_URL=http://localhost:3001/api
REACT_APP_STREAMING_API_URL=http://localhost:3002/api
REACT_APP_STREAMING_PUBLIC_URL=http://localhost:3002
REACT_APP_ADMIN_API_URL=http://localhost:3003/api/admin
REACT_APP_CHAT_API_URL=http://localhost:3004/api/chat
REACT_APP_CHAT_SOCKET_URL=http://localhost:3004
```

### 2.3 Test Locally with Docker Compose
```bash
# Build and start all services
docker-compose up --build

# Verify all 6 containers are running
docker-compose ps

# Open in browser
# http://localhost:3000
```

Expected containers running:
- `mongo` — MongoDB 6 on port 27017
- `auth` — Auth Service on port 3001
- `streaming` — Streaming Service on port 3002
- `admin` — Admin Service on port 3003
- `chat` — Chat Service on port 3004
- `frontend` — React (Nginx) on port 3000

```bash
# Stop when done
docker-compose down
```

### 2.4 Create ECR Repositories

```bash
# Linux/macOS: make script executable
chmod +x scripts/*.sh

# Run ECR creation script
./scripts/create-ecr-repos.sh
```

This creates 5 ECR repos with image scanning enabled:
- `gs-streamingapp-frontend`
- `gs-streamingapp-auth`
- `gs-streamingapp-streaming`
- `gs-streamingapp-admin`
- `gs-streamingapp-chat`

<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/2.4%20Create%20ECR%20Repositories%201.0.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/2.4%20Create%20ECR%20Repositories%201.1.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/2.4%20Create%20ECR%20Repositories%201.2.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/2.4%20Create%20ECR%20Repositories%201.3.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/2.4%20Create%20ECR%20Repositories%201.4.png"/>

**Windows PowerShell alternative:**
```powershell
$AWS_REGION = "ap-south-1"
$AWS_ACCOUNT_ID = (aws sts get-caller-identity --query Account --output text)

$repos = @("gs-streamingapp-frontend","gs-streamingapp-auth","gs-streamingapp-streaming","gs-streamingapp-admin","gs-streamingapp-chat")
foreach ($repo in $repos) {
    aws ecr create-repository `
        --repository-name $repo `
        --region $AWS_REGION `
        --image-scanning-configuration scanOnPush=true
    Write-Host "Created: $repo"
}
```

### 2.5 Build and Push Docker Images to ECR

Set the production API URLs (replace `your-domain.com` with your actual ALB DNS or domain):
```bash
export REACT_APP_AUTH_API_URL="http://your-alb-dns.ap-south-1.elb.amazonaws.com/api/auth"
export REACT_APP_STREAMING_API_URL="http://your-alb-dns.ap-south-1.elb.amazonaws.com/api/streaming"
export REACT_APP_STREAMING_PUBLIC_URL="http://your-alb-dns.ap-south-1.elb.amazonaws.com"
export REACT_APP_ADMIN_API_URL="http://your-alb-dns.ap-south-1.elb.amazonaws.com/api/admin"
export REACT_APP_CHAT_API_URL="http://your-alb-dns.ap-south-1.elb.amazonaws.com/api/chat"
export REACT_APP_CHAT_SOCKET_URL="http://your-alb-dns.ap-south-1.elb.amazonaws.com"
```

> **Note:** If you don't have the ALB URL yet, use `localhost` values for initial push and re-push after Step 5.

```bash
./scripts/build-and-push.sh v1.0.0
```

What this script does internally:
1. Calls `aws sts get-caller-identity` to get your account ID
2. Calls `aws ecr get-login-password` → logs Docker into ECR
3. Builds all 5 images with `--build-arg REACT_APP_*` for frontend
4. Tags each as `v1.0.0`, `<git-commit-hash>`, and `latest`
5. Pushes all tags to ECR

<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/2.5%20Build%20and%20Push%20Docker%20Images%20to%20ECR%201.0.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/2.5%20Build%20and%20Push%20Docker%20Images%20to%20ECR%201.1.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/2.5%20Build%20and%20Push%20Docker%20Images%20to%20ECR%201.2.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/2.5%20Build%20and%20Push%20Docker%20Images%20to%20ECR%201.3.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/2.5%20Build%20and%20Push%20Docker%20Images%20to%20ECR%201.4.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/2.5%20Build%20and%20Push%20Docker%20Images%20to%20ECR%201.5.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/2.5%20Build%20and%20Push%20Docker%20Images%20to%20ECR%201.6.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/2.5%20Build%20and%20Push%20Docker%20Images%20to%20ECR%201.7.png"/>

**Verify images were pushed:**
```bash
aws ecr list-images --repository-name gs-streamingapp-frontend --region ap-south-1
aws ecr list-images --repository-name gs-streamingapp-auth --region ap-south-1
aws ecr list-images --repository-name gs-streamingapp-streaming --region ap-south-1
aws ecr list-images --repository-name gs-streamingapp-admin --region ap-south-1
aws ecr list-images --repository-name gs-streamingapp-chat --region ap-south-1
```
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/2.5%20Build%20and%20Push%20Docker%20Images%20to%20ECR%201.8%20Verify%20images%20were%20pushed%201.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/2.5%20Build%20and%20Push%20Docker%20Images%20to%20ECR%201.9%20Verify%20images%20were%20pushed%202.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/2.5%20Build%20and%20Push%20Docker%20Images%20to%20ECR%201.10%20Verify%20images%20were%20pushed%203.png"/>

---

## STEP 3 — AWS Environment Setup

### 3.1 Create IAM User (AWS Console)
1. Open **AWS Console → IAM → Users → Create user**
2. Username: `streamingapp-deployer`
3. Attach these policies directly:
   - `AmazonEKSClusterPolicy`
   - `AmazonEKSServicePolicy`
   - `AmazonEC2ContainerRegistryFullAccess`
   - `CloudWatchLogsFullAccess`
   - `AmazonS3FullAccess`
   - `IAMFullAccess` *(needed for eksctl to create service account roles)*
4. **Security credentials → Create access key** → save the key pair

### 3.2 Configure AWS CLI
```bash
aws configure
# AWS Access Key ID:     AKIAxxxxxxxxxxxxxxxx
# AWS Secret Access Key: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# Default region name:   ap-south-1
# Default output format: json
```

### 3.3 Verify Configuration
```bash
aws sts get-caller-identity
# Expected output:
# {
#     "UserId": "AIDAXXXXXXXXXXXXXXXXX",
#     "Account": "123456789012",
#     "Arn": "arn:aws:iam::123456789012:user/streamingapp-deployer"
# }
```

### 3.4 Create S3 Bucket for Video Storage
```bash
# Create bucket (bucket name must be globally unique)
aws s3 mb s3://streamingapp-videos-YOUR_ACCOUNT_ID --region ap-south-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket streamingapp-videos-YOUR_ACCOUNT_ID \
  --versioning-configuration Status=Enabled

# Enable CORS for browser access
aws s3api put-bucket-cors \
  --bucket streamingapp-videos-YOUR_ACCOUNT_ID \
  --cors-configuration '{
    "CORSRules": [{
      "AllowedHeaders": ["*"],
      "AllowedMethods": ["GET","PUT","POST","DELETE"],
      "AllowedOrigins": ["*"],
      "MaxAgeSeconds": 3000
    }]
  }'
```

<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/3.4%20Create%20S3%20Bucket%20for%20Video%20Storage.png"/>

Update your `.env` with the bucket name:
```ini
AWS_S3_BUCKET=streamingapp-videos-YOUR_ACCOUNT_ID
```

---

## STEP 4 — Continuous Integration (CI) using Jenkins

### 4.1 Access Jenkins
Use the provided Jenkins URL:
- **URL:** https://jenkinsacademics.herovired.com/
- **Username:** `username`
- **Password:** `password`

*(Skip 4.2 and 4.3 if using the provided Jenkins URL)*

### 4.2 (Optional) Install Jenkins on Your Own EC2

**Launch EC2 instance:**
- AMI: Ubuntu 22.04 LTS
- Instance type: `t3.medium`
- Security Group inbound rules:
  - Port 22 (SSH) from your IP
  - Port 8080 (Jenkins) from anywhere (0.0.0.0/0)

```bash
# SSH into instance
ssh -i your-key.pem ubuntu@<EC2-PUBLIC-IP>

# Install Java 11
sudo apt update
sudo apt install -y openjdk-11-jdk

# Add Jenkins repo
wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -
sudo sh -c 'echo deb https://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'

# Install Jenkins
sudo apt update
sudo apt install -y jenkins

# Start and enable Jenkins
sudo systemctl start jenkins
sudo systemctl enable jenkins
sudo systemctl status jenkins

# Get initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Access at: `http://<EC2-PUBLIC-IP>:8080`

### 4.3 (Optional) Install Docker on Jenkins EC2

```bash
# Install Docker on the Jenkins server (so Jenkins can build images)
sudo apt install -y docker.io
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
sudo systemctl restart docker
```

### 4.4 Install Required Jenkins Plugins

Go to **Manage Jenkins → Plugin Manager → Available plugins**, search and install:

| Plugin Name | Purpose |
|---|---|
| Docker Pipeline | Build Docker images in pipeline |
| Amazon ECR | ECR authentication |
| AWS Steps | AWS CLI integration |
| Pipeline AWS | AWS pipeline steps |
| Kubernetes | K8s deployment |
| GitHub Integration | Webhook & SCM polling |
| Slack Notification | ChatOps alerts (bonus) |

Click **Install without restart** → wait → click **Restart Jenkins when installation is complete**.

### 4.5 Add Jenkins Credentials

Go to: **Manage Jenkins → Credentials → System → Global credentials (unrestricted) → Add Credentials**

Add these 3 credentials:

**Credential 1 — AWS Credentials:**
- Kind: `AWS Credentials`
- ID: `aws-credentials`
- Access Key ID: your AWS access key
- Secret Access Key: your AWS secret key

**Credential 2 — AWS Account ID:**
- Kind: `Secret text`
- ID: `aws-account-id`
- Secret: your 12-digit AWS account ID (e.g. `123456789012`)

**Credential 3 — SNS Topic ARN:**
- Kind: `Secret text`
- ID: `sns-topic-arn`
- Secret: `arn:aws:sns:ap-south-1:123456789012:streamingapp-deployments`
  *(create SNS topic in Step 9 first, then come back and update this)*

<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/4.5%20Add%20Jenkins%20Credentials.png"/>

### 4.6 Create the Jenkins Pipeline Job

1. Click **New Item**
2. Name: `StreamingApp-CI-CD`
3. Type: **Pipeline** → Click **OK**
4. Configure as follows:

**General section:**
- Description: `StreamingApp CI/CD Pipeline`

**Build Triggers section:**
- Check: ✅ `GitHub hook trigger for GITScm polling`

**Pipeline section:**
- Definition: `Pipeline script from SCM`
- SCM: `Git`
- Repository URL: `https://github.com/YOUR_USERNAME/StreamingApp.git`
- Credentials: Add your GitHub credentials (username + personal access token)
- Branch Specifier: `*/main`
- Script Path: `Jenkinsfile`

5. Click **Save**

<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/4.6%20Create%20the%20Jenkins%20Pipeline%20Job.png"/>

### 4.7 Understand the Jenkinsfile Pipeline Stages

The [Jenkinsfile](Jenkinsfile) has these stages:

| Stage | What it does |
|---|---|
| Checkout | Pulls code + sends SNS "build started" notification |
| Pre-build Validation | Verifies Docker, AWS CLI, and credentials |
| Run Tests | Runs `npm test` for frontend (parallel with backend tests) |
| Login to ECR | `aws ecr get-login-password \| docker login` |
| Build Images | Builds all 5 Docker images in parallel |
| Security Scan | (Placeholder for Trivy/ECR scanning) |
| Push to ECR | Pushes all images tagged with `BUILD_NUMBER` and `latest` |
| Deploy to EKS | Helm deploy (only if `DEPLOY_TO_EKS=true` parameter is set) |
| Post (success/failure) | Sends SNS notification to Slack/Teams/Telegram |

**Pipeline parameters (set when triggering a build):**
- `DEPLOYMENT_ENV` — `dev` / `staging` / `production`
- `DEPLOY_TO_EKS` — `true` / `false`
- `RUN_TESTS` — `true` / `false`

### 4.8 Configure GitHub Webhook

In your GitHub fork repository:
1. Go to **Settings → Webhooks → Add webhook**
2. Fill in:
   - **Payload URL:** `https://jenkinsacademics.herovired.com/github-webhook/`
     *(or `http://YOUR_EC2_IP:8080/github-webhook/` if using your own Jenkins)*
   - **Content type:** `application/json`
   - **Which events:** `Just the push event`
   - **Active:** ✅ checked
3. Click **Add webhook**
4. GitHub will send a test ping → verify a green ✓ appears

<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/4.8%20Configure%20GitHub%20Webhook.png"/>

### 4.9 Trigger First Build

1. In Jenkins, go to `StreamingApp-CI-CD`
2. Click **Build with Parameters**
3. Set: `DEPLOYMENT_ENV=dev`, `DEPLOY_TO_EKS=false`, `RUN_TESTS=true`
4. Click **Build**
5. Click the build number → **Console Output** to watch logs

**Verify each stage passes.** Fix any errors (usually credential issues) before proceeding.

<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/4.9%20Trigger%20First%20Build.png"/>

---

## STEP 5 — Kubernetes Deployment (EKS)

### 5.1 Create EKS Cluster

```bash
# Run from project root (Linux/macOS)
chmod +x scripts/create-eks-cluster.sh
./scripts/create-eks-cluster.sh
```

<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/5.1%20Create%20EKS%20Cluster%201.0.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/5.1%20Create%20EKS%20Cluster%201.1.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/5.1%20Create%20EKS%20Cluster%201.2.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/5.1%20Create%20EKS%20Cluster%201.3.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/5.1%20Create%20EKS%20Cluster%201.4.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/5.1%20Create%20EKS%20Cluster%201.5.png"/>

**Windows PowerShell:**
```powershell
$env:CLUSTER_NAME = "streamingapp-cluster"
$env:AWS_REGION = "ap-south-1"
bash scripts/create-eks-cluster.sh   # requires Git Bash or WSL
```

**Or manually with eksctl:**
```bash
eksctl create cluster \
  --name streamingapp-cluster \
  --region ap-south-1 \
  --version 1.28 \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 2 \
  --nodes-max 10 \
  --managed \
  --with-oidc \
  --alb-ingress-access \
  --full-ecr-access
```

> This takes **15–20 minutes**. The script also:
> - Installs **AWS Load Balancer Controller** (required for ALB/Ingress)
> - Installs **Metrics Server** (required for HPA/autoscaling)
> - Installs **EBS CSI Driver** (required for persistent volumes / MongoDB)
> - Creates namespaces: `dev`, `staging`, `production`

### 5.2 Configure kubectl

```bash
aws eks update-kubeconfig --name streamingapp-cluster --region ap-south-1

# Verify access
kubectl get nodes
# Expected: 3 nodes in Ready state
kubectl get namespaces
# Expected: dev, staging, production among others
```

### 5.3 Configure Helm Values

Edit `k8s/helm/streamingapp/values.yaml`:

```yaml
# Line 12 — set your ECR registry
imageRegistry:
  url: "123456789012.dkr.ecr.ap-south-1.amazonaws.com"   # replace with your account ID

imageTag: "v1.0.0"   # or "latest"
```

> The secrets (`jwtSecret`, `awsAccessKeyId`, etc.) are passed at deploy-time via `--set`, not stored in values.yaml.

### 5.4 Deploy Application to EKS

```bash
./scripts/deploy-to-eks.sh dev v1.0.0
```

The script will interactively prompt for:
- `JWT_SECRET` — press Enter to auto-generate, or enter your value
- `AWS_ACCESS_KEY_ID` — your AWS key
- `AWS_SECRET_ACCESS_KEY` — your AWS secret
- `AWS_S3_BUCKET` — your S3 bucket name
- `AWS_CDN_URL` — optional CloudFront URL

<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/5.4%20Deploy%20Application%20to%20EKS.png"/>

**Or deploy manually with full Helm command:**
```bash
helm upgrade --install streamingapp ./k8s/helm/streamingapp \
  --namespace dev \
  --create-namespace \
  --set imageRegistry.url="123456789012.dkr.ecr.ap-south-1.amazonaws.com" \
  --set imageTag="v1.0.0" \
  --set secrets.jwtSecret="$(openssl rand -hex 32)" \
  --set secrets.awsAccessKeyId="AKIAxxxxxxxxxxxxxxxx" \
  --set secrets.awsSecretAccessKey="your-secret-key" \
  --set secrets.awsS3Bucket="streamingapp-videos-123456789012" \
  --set secrets.awsCdnUrl="" \
  --wait \
  --timeout 10m
```

### 5.5 Verify Deployment

```bash
# Watch pods come up (Ctrl+C when all are Running)
kubectl get pods -n dev -w

# Expected: all pods in Running state
# NAME                                      READY   STATUS    RESTARTS
# streamingapp-frontend-xxxxxxx             1/1     Running   0
# streamingapp-auth-xxxxxxx                 1/1     Running   0
# streamingapp-streaming-xxxxxxx            1/1     Running   0
# streamingapp-admin-xxxxxxx                1/1     Running   0
# streamingapp-chat-xxxxxxx                 1/1     Running   0
# streamingapp-mongodb-xxxxxxx              1/1     Running   0

# Get services (look for frontend EXTERNAL-IP)
kubectl get svc -n dev

# Get ingress
kubectl get ingress -n dev

# Check rollout status
kubectl rollout status deployment -n dev
```

<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/5.5%20Verify%20Deployment.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/5.5%20Verify%20Deployment%201.png"/>

### 5.6 Get the Application URL

```bash
# Get the Load Balancer DNS name for the frontend
kubectl get svc streamingapp-frontend -n dev \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Example output:
# abc123.ap-south-1.elb.amazonaws.com
```

Open `http://abc123.ap-south-1.elb.amazonaws.com` in your browser.

### 5.7 Configure Autoscaling

The Helm chart already configures HPA. Verify it:
```bash
kubectl get hpa -n dev
# Shows HPA for each service with CPU target and min/max replicas

kubectl describe hpa -n dev

# Manual scaling
kubectl scale deployment streamingapp-streaming --replicas=4 -n dev

# Check resource usage
kubectl top pods -n dev
kubectl top nodes
```

### 5.8 Re-build Frontend with Production URLs

Now that you have the ALB URL, rebuild the frontend image with correct API URLs:
```bash
export REACT_APP_AUTH_API_URL="http://abc123.ap-south-1.elb.amazonaws.com/api/auth"
export REACT_APP_STREAMING_API_URL="http://abc123.ap-south-1.elb.amazonaws.com/api/streaming"
export REACT_APP_STREAMING_PUBLIC_URL="http://abc123.ap-south-1.elb.amazonaws.com"
export REACT_APP_ADMIN_API_URL="http://abc123.ap-south-1.elb.amazonaws.com/api/admin"
export REACT_APP_CHAT_API_URL="http://abc123.ap-south-1.elb.amazonaws.com/api/chat"
export REACT_APP_CHAT_SOCKET_URL="http://abc123.ap-south-1.elb.amazonaws.com"

./scripts/build-and-push.sh v1.0.1

# Re-deploy
./scripts/deploy-to-eks.sh dev v1.0.1
```
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/5.8%20Re-build%20Frontend%20with%20Production%20URLs.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/5.8%20Re-build%20Frontend%20with%20Production%20URLs%201.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/5.8%20Re-build%20Frontend%20with%20Production%20URLs%202.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/5.8%20Re-build%20Frontend%20with%20Production%20URLs%203.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/5.8%20Re-build%20Frontend%20with%20Production%20URLs%204.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/5.8%20Re-build%20Frontend%20with%20Production%20URLs%205.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/5.8%20Re-build%20Frontend%20with%20Production%20URLs%206.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/5.8%20Re-build%20Frontend%20with%20Production%20URLs%207.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/5.8%20Re-build%20Frontend%20with%20Production%20URLs%208.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/5.8%20Re-build%20Frontend%20with%20Production%20URLs%209.png"/>

---

## STEP 6 — ChatOps Integration

### 6.1 Run the ChatOps Setup Script

```bash
# For Slack
./scripts/setup-chatops.sh slack

# For Microsoft Teams
./scripts/setup-chatops.sh teams

# For Telegram
./scripts/setup-chatops.sh telegram
```
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/STEP%209%20(Bonus)%20%E2%80%94%20ChatOps%20Integration.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/STEP%209%20(Bonus)%20%E2%80%94%20ChatOps%20Integration%201.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/STEP%209%20(Bonus)%20%E2%80%94%20ChatOps%20Integration%202.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/streamingapp-sns-to-slack-Functions-Lambda.png"/>

### 6.2 Slack Integration

**Create Slack Webhook:**
1. Go to https://api.slack.com/apps → **Create New App → From scratch**
2. App Name: `StreamingApp Bot` → select workspace
3. **Features → Incoming Webhooks** → toggle **On**
4. **Add New Webhook to Workspace** → choose channel `#deployments` → **Allow**
5. Copy the webhook URL: `https://hooks.slack.com/services/T.../B.../...`

<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/9.3%20Slack%20Integration.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/9.3%20Slack%20Integration%201.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/9.3%20Slack%20Integration%202.png"/>

---
## STEP 7 — Access website using elb url and perform action

<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/5.9%20%201.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/5.9%202.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/5.9%203.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/5.9%204.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/5.9%205.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/5.9%206.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/5.9%207.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/5.9%208.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/5.9%209.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/5.9%2010.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/5.9%2011.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/6.6%20s3%20bucket.png"/>


---
## STEP 7 — Github webhook trigger and Jenkins pipeline

<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/6.5.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/6.3.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/6.0.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/6.2.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/6.1.png"/>
<img src="https://github.com/ghanshyamca/StreamingApp/blob/main/Image/6.7.png"/>





