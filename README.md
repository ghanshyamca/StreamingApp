# Graded Project: Orchestration and Scaling — Complete Step-by-Step Guide

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

## Prerequisites — Install Tools First

### On Windows (PowerShell as Administrator)
```powershell
# 1. AWS CLI
msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi
# Restart terminal after install

# 2. Docker Desktop
# Download from: https://www.docker.com/products/docker-desktop/

# 3. kubectl
curl.exe -LO "https://dl.k8s.io/release/v1.28.0/bin/windows/amd64/kubectl.exe"
# Move kubectl.exe to C:\Windows\System32\ or add its folder to PATH

# 4. eksctl and Helm (Chocolatey required)
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
choco install eksctl -y
choco install kubernetes-helm -y

# 5. Git
choco install git -y
```

### On Linux/macOS (Terminal)
```bash
# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### Verify all tools
```bash
aws --version
docker --version
kubectl version --client
eksctl version
helm version
git --version
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

**Verify images were pushed:**
```bash
aws ecr list-images --repository-name gs-streamingapp-frontend --region ap-south-1
aws ecr list-images --repository-name gs-streamingapp-auth --region ap-south-1
aws ecr list-images --repository-name gs-streamingapp-streaming --region ap-south-1
aws ecr list-images --repository-name gs-streamingapp-admin --region ap-south-1
aws ecr list-images --repository-name gs-streamingapp-chat --region ap-south-1
```

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

Update your `.env` with the bucket name:
```ini
AWS_S3_BUCKET=streamingapp-videos-YOUR_ACCOUNT_ID
```

---

## STEP 4 — Continuous Integration (CI) using Jenkins

### 4.1 Access Jenkins
Use the provided Jenkins URL:
- **URL:** https://jenkinsacademics.herovired.com/
- **Username:** `herovired`
- **Password:** `herovired`

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

### 4.9 Trigger First Build

1. In Jenkins, go to `StreamingApp-CI-CD`
2. Click **Build with Parameters**
3. Set: `DEPLOYMENT_ENV=dev`, `DEPLOY_TO_EKS=false`, `RUN_TESTS=true`
4. Click **Build**
5. Click the build number → **Console Output** to watch logs

**Verify each stage passes.** Fix any errors (usually credential issues) before proceeding.

---

## STEP 5 — Kubernetes Deployment (EKS)

### 5.1 Create EKS Cluster

```bash
# Run from project root (Linux/macOS)
chmod +x scripts/create-eks-cluster.sh
./scripts/create-eks-cluster.sh
```

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

---

## STEP 6 — Monitoring and Logging

### 6.1 Set Up CloudWatch Container Insights

```bash
chmod +x scripts/setup-monitoring.sh
./scripts/setup-monitoring.sh
```

This script:
1. Creates `amazon-cloudwatch` namespace in Kubernetes
2. Creates a service account with `CloudWatchAgentServerPolicy`
3. Deploys **CloudWatch Agent** as a DaemonSet (metrics)
4. Deploys **Fluent Bit** as a DaemonSet (log forwarding)
5. Creates CloudWatch Log Group: `/aws/eks/streamingapp-cluster/streamingapp`
6. Creates CloudWatch Alarms (CPU > 80%, Memory > 80%, error rate, pod restarts)

**Verify agents are running:**
```bash
kubectl get pods -n amazon-cloudwatch
# Expected: cloudwatch-agent and fluent-bit pods Running on each node
```

### 6.2 CloudWatch Log Groups Created

| Log Group | Contents |
|---|---|
| `/aws/eks/streamingapp-cluster/application` | Application logs |
| `/aws/eks/streamingapp-cluster/cluster` | EKS cluster logs |
| `/aws/containerinsights/streamingapp-cluster/performance` | CPU, memory, network metrics |

### 6.3 View Logs via AWS CLI

```bash
# Tail live logs
aws logs tail /aws/eks/streamingapp-cluster/streamingapp --follow --region ap-south-1

# Filter for errors in the last hour
aws logs filter-log-events \
  --log-group-name /aws/eks/streamingapp-cluster/streamingapp \
  --filter-pattern "ERROR" \
  --start-time $(date -u -d '1 hour ago' +%s000) \
  --region ap-south-1
```

**Windows PowerShell:**
```powershell
$startTime = [DateTimeOffset]::UtcNow.AddHours(-1).ToUnixTimeMilliseconds()
aws logs filter-log-events `
  --log-group-name /aws/eks/streamingapp-cluster/streamingapp `
  --filter-pattern "ERROR" `
  --start-time $startTime `
  --region ap-south-1
```

### 6.4 View Logs via kubectl

```bash
# Follow logs per deployment
kubectl logs -f deployment/streamingapp-frontend -n dev
kubectl logs -f deployment/streamingapp-auth -n dev
kubectl logs -f deployment/streamingapp-streaming -n dev
kubectl logs -f deployment/streamingapp-admin -n dev
kubectl logs -f deployment/streamingapp-chat -n dev

# View all pods of a service at once
kubectl logs -f -l app.kubernetes.io/component=streaming -n dev

# Previous crashed container logs
kubectl logs --previous <pod-name> -n dev
```

### 6.5 View in AWS Console

1. Open **AWS Console → CloudWatch → Container Insights**
2. Select: **EKS Clusters** → `streamingapp-cluster`
3. View pre-built dashboards for: CPU, Memory, Network, Pod count

### 6.6 View / Edit CloudWatch Alarms

```bash
# List all alarms
aws cloudwatch describe-alarms --region ap-south-1

# Check alarm states
aws cloudwatch describe-alarms \
  --alarm-names "streamingapp-cluster-high-cpu" \
  --query 'MetricAlarms[0].StateValue' \
  --output text
```

| Alarm | Metric | Threshold |
|---|---|---|
| CPU Utilization | `CPUUtilization` | > 80% for 10 min |
| Memory Utilization | `MemoryUtilization` | > 80% for 10 min |
| High Error Rate | `5XXError` | > 10 in 5 min |
| Pod Restarts | `PodRestartCount` | > 3 in 15 min |

---

## STEP 7 — Documentation

### 7.1 Existing Documentation in Repo

All documentation is already in the `docs/` directory:

| File | Contents |
|---|---|
| `docs/DEPLOYMENT_GUIDE.md` | Full deployment reference |
| `docs/MONITORING.md` | CloudWatch + Fluentd config details |
| `docs/CHATOPS.md` | SNS + Lambda + Slack/Teams/Telegram setup |
| `docs/QUICK_REFERENCE.md` | Common command cheat sheet |
| `docs/SUBMISSION_GUIDE.md` | Submission checklist |

### 7.2 Add Screenshots and Diagrams

Document the following for your submission:

- Screenshot of ECR repositories with pushed images
- Screenshot of EKS cluster nodes (`kubectl get nodes`)
- Screenshot of all pods running (`kubectl get pods -n dev`)
- Screenshot of frontend UI loading in browser
- Screenshot of Jenkins pipeline with green stages
- Screenshot of CloudWatch Container Insights dashboard
- Screenshot of CloudWatch Alarms
- Screenshot of Slack/Teams/Telegram receiving SNS notification (bonus)

### 7.3 Commit and Push Documentation

```bash
git add docs/ PROJECT_STEPS.md PROJECT_SUBMISSION_README.md
git commit -m "docs: add complete deployment documentation and screenshots"
git push origin main
```

---

## STEP 8 — Final Validation

### 8.1 Check All Pods Are Running

```bash
kubectl get pods -n dev
# Every pod should show: STATUS=Running, RESTARTS=0 (or very low)
```

### 8.2 Health Check All Services

```bash
# Get ALB URL
ALB=$(kubectl get svc streamingapp-frontend -n dev \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Frontend: http://$ALB"

# Health endpoints
curl http://$ALB/api/health                    # admin
curl http://$(kubectl get svc streamingapp-auth -n dev -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo $ALB)/api/health

# Or port-forward to test directly
kubectl port-forward svc/streamingapp-auth 3001:3001 -n dev &
curl http://localhost:3001/api/health
# Expected: {"success":true,"service":"auth","status":"ok"}  (for auth)

kubectl port-forward svc/streamingapp-admin 3003:3003 -n dev &
curl http://localhost:3003/api/health
# Expected: {"success":true,"service":"admin","status":"ok"}
```

### 8.3 Application Smoke Tests (Browser)

1. **Open** `http://<ALB-DNS>` in browser
2. **Register** a new user account
3. **Login** with the account
4. **Admin Dashboard** (requires admin role):
   - Create an admin user in MongoDB OR update a user's `role` field to `"admin"`
   - Upload a video + thumbnail (requires S3 credentials to be correct)
5. **Browse page** — verify uploaded video appears
6. **Video Player** — click play and verify streaming works
7. **Chat** — open same video in two browser tabs, send messages, verify they appear in both tabs
8. **Admin route protection** — try accessing `/admin` as a regular user → should redirect to `/browse`

**Fix admin role (if needed):**
```bash
# Port-forward MongoDB
kubectl port-forward svc/streamingapp-mongodb 27017:27017 -n dev

# Connect with mongosh (in a new terminal)
mongosh mongodb://localhost:27017/streamingapp

# Update user to admin
db.users.updateOne(
  { email: "your@email.com" },
  { $set: { role: "admin" } }
)
db.users.findOne({ email: "your@email.com" }, { role: 1, email: 1 })
exit
```

### 8.4 Verify CI/CD Pipeline (Auto-trigger)

```bash
# Make a small change to trigger a build
echo "# Validated $(date)" >> README.md
git add README.md
git commit -m "ci: trigger validation build"
git push origin main
```

- Open Jenkins → confirm a new build triggers automatically via webhook
- Verify all pipeline stages pass (green)
- Confirm new image appears in ECR with new build number tag

### 8.5 Verify Auto-scaling

```bash
# Generate load to trigger HPA (optional smoke test)
kubectl run -i --tty load-test --rm --image=busybox --restart=Never -- \
  /bin/sh -c "while true; do wget -q -O- http://streamingapp-streaming:3002/api/health; done"

# In another terminal, watch HPA respond
kubectl get hpa -n dev -w
```

---

## STEP 9 (Bonus) — ChatOps Integration

### 9.1 Run the ChatOps Setup Script

```bash
# For Slack
./scripts/setup-chatops.sh slack

# For Microsoft Teams
./scripts/setup-chatops.sh teams

# For Telegram
./scripts/setup-chatops.sh telegram
```

### 9.2 Manual Setup (if not using script)

**Create SNS Topics:**
```bash
# Deployment notifications
DEPLOY_ARN=$(aws sns create-topic \
  --name streamingapp-deployments \
  --region ap-south-1 \
  --query 'TopicArn' --output text)

# Error alerts
ALERT_ARN=$(aws sns create-topic \
  --name streamingapp-alerts \
  --region ap-south-1 \
  --query 'TopicArn' --output text)

# Monitoring alerts
MONITOR_ARN=$(aws sns create-topic \
  --name streamingapp-monitoring \
  --region ap-south-1 \
  --query 'TopicArn' --output text)

echo "Deployment ARN: $DEPLOY_ARN"
echo "Alert ARN:      $ALERT_ARN"
echo "Monitor ARN:    $MONITOR_ARN"
```

### 9.3 Slack Integration

**Create Slack Webhook:**
1. Go to https://api.slack.com/apps → **Create New App → From scratch**
2. App Name: `StreamingApp Bot` → select workspace
3. **Features → Incoming Webhooks** → toggle **On**
4. **Add New Webhook to Workspace** → choose channel `#deployments` → **Allow**
5. Copy the webhook URL: `https://hooks.slack.com/services/T.../B.../...`

**Create Lambda execution IAM role:**
```bash
aws iam create-role \
  --role-name StreamingAppLambdaSNSRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "lambda.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }'

aws iam attach-role-policy \
  --role-name StreamingAppLambdaSNSRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# Get the role ARN
ROLE_ARN=$(aws iam get-role \
  --role-name StreamingAppLambdaSNSRole \
  --query 'Role.Arn' --output text)
```

**Deploy the Lambda function** (code is at `lambda/sns-to-slack.py`):
```bash
cd lambda
zip sns-to-slack.zip sns-to-slack.py

LAMBDA_ARN=$(aws lambda create-function \
  --function-name sns-to-slack \
  --runtime python3.9 \
  --handler sns-to-slack.lambda_handler \
  --zip-file fileb://sns-to-slack.zip \
  --role $ROLE_ARN \
  --environment "Variables={SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL}" \
  --region ap-south-1 \
  --query 'FunctionArn' --output text)

echo "Lambda ARN: $LAMBDA_ARN"
cd ..
```

**Subscribe Lambda to SNS:**
```bash
# Allow SNS to invoke Lambda
aws lambda add-permission \
  --function-name sns-to-slack \
  --statement-id sns-invoke \
  --action lambda:InvokeFunction \
  --principal sns.amazonaws.com \
  --source-arn $DEPLOY_ARN \
  --region ap-south-1

# Subscribe
aws sns subscribe \
  --topic-arn $DEPLOY_ARN \
  --protocol lambda \
  --notification-endpoint $LAMBDA_ARN \
  --region ap-south-1
```

### 9.4 Teams Integration

Lambda function is at `lambda/sns-to-teams.py`. Use the same steps as Slack but:
- Get Teams webhook URL: **Teams channel → ... → Connectors → Incoming Webhook → Add → Copy URL**
- Deploy `sns-to-teams.zip` with env var `TEAMS_WEBHOOK_URL` instead of `SLACK_WEBHOOK_URL`

### 9.5 Telegram Integration

Lambda function is at `lambda/sns-to-telegram.py`. Env vars needed:
- `TELEGRAM_BOT_TOKEN` — get from @BotFather on Telegram (`/newbot`)
- `TELEGRAM_CHAT_ID` — get from @userinfobot

### 9.6 Update Jenkins Credential with SNS ARN

Go to **Jenkins → Manage Jenkins → Credentials** → find `sns-topic-arn` → update value with `$DEPLOY_ARN`.

### 9.7 Test the Notification

```bash
aws sns publish \
  --topic-arn $DEPLOY_ARN \
  --subject "✅ StreamingApp ChatOps Test" \
  --message "ChatOps is working! Deployment notifications are active." \
  --region ap-south-1
```

Verify the message appears in your Slack/Teams/Telegram channel.

---

## Submission Checklist

Before submitting, verify all items:

```
[ ] Fork created at https://github.com/YOUR_USERNAME/StreamingApp
[ ] All .env files created from .env.example templates
[ ] docker-compose up --build works locally
[ ] 5 ECR repositories created with images pushed
[ ] EKS cluster running with 3 nodes
[ ] All 6 pods Running in dev namespace
[ ] Frontend accessible via ALB URL in browser
[ ] User registration and login working
[ ] Video upload via admin dashboard working (requires S3)
[ ] Video playback working
[ ] Chat working between browser tabs
[ ] Jenkins pipeline with all green stages
[ ] GitHub webhook auto-triggers Jenkins on git push
[ ] CloudWatch Container Insights showing metrics
[ ] CloudWatch Log Groups receiving logs
[ ] CloudWatch Alarms configured
[ ] All documentation pushed to GitHub
[ ] SNS + Lambda ChatOps notifications working (bonus)
```

### Final Push
```bash
git add .
git commit -m "feat: complete graded project - all steps implemented"
git push origin main
```

### Submission File
Create a file named `submission.txt`:
```
GitHub Repository: https://github.com/YOUR_USERNAME/StreamingApp
Application URL:   http://YOUR_ALB_DNS_HERE
Jenkins URL:       https://jenkinsacademics.herovired.com/
EKS Cluster:       streamingapp-cluster (ap-south-1)
ECR Registry:      123456789012.dkr.ecr.ap-south-1.amazonaws.com
```

Upload `submission.txt` to **Vlearn**.

---

## Quick Reference — Most Used Commands

```bash
# Check pod status
kubectl get pods -n dev

# View logs
kubectl logs -f deployment/streamingapp-auth -n dev

# Restart a deployment
kubectl rollout restart deployment/streamingapp-auth -n dev

# Scale up
kubectl scale deployment streamingapp-streaming --replicas=5 -n dev

# Get frontend URL
kubectl get svc streamingapp-frontend -n dev

# Run a new deploy after code change
./scripts/build-and-push.sh v1.0.2
./scripts/deploy-to-eks.sh dev v1.0.2

# Delete all dev resources (cleanup)
helm uninstall streamingapp -n dev

# Delete EKS cluster (ONLY when done — this is irreversible)
eksctl delete cluster --name streamingapp-cluster --region ap-south-1
```
