# StreamingApp — Graded Project: Orchestration and Scaling

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

## 2. Step 1 — Version Control with Git

### 1.1 Fork the Repository

1. Go to https://github.com/UnpredictablePrashant/StreamingApp
2. Click **Fork** → select your GitHub account

### 1.2 Clone Your Fork

```bash
git clone https://github.com/YOUR_USERNAME/StreamingApp.git
cd StreamingApp
```

### 1.3 Add Upstream Remote & Sync

```bash
# Add the original repo as upstream
git remote add upstream https://github.com/UnpredictablePrashant/StreamingApp.git

# Fetch and merge latest changes
git fetch upstream
git merge upstream/main

# Push synced changes to your fork
git push origin main
```

---

## 5. Step 2 — Containerize & Push to Amazon ECR

### 2.1 Review Dockerfiles

Dockerfiles are pre-created for all services:

| Service | Dockerfile Path |
|---|---|
| Frontend | `frontend/Dockerfile` |
| Auth Service | `backend/authService/Dockerfile` |
| Streaming Service | `backend/streamingService/Dockerfile` |
| Admin Service | `backend/adminService/Dockerfile` |
| Chat Service | `backend/chatService/Dockerfile` |

### 2.2 Create ECR Repositories

```bash
# Make scripts executable (Linux/macOS)
chmod +x scripts/*.sh

# Run the ECR creation script
./scripts/create-ecr-repos.sh
```

This creates the following repositories in your AWS account:
- `gs-streamingapp-frontend`
- `gs-streamingapp-auth`
- `gs-streamingapp-streaming`
- `gs-streamingapp-admin`
- `gs-streamingapp-chat`

### 2.3 Set Environment Variables

```bash
export REACT_APP_AUTH_API_URL="https://your-domain.com/api/auth"
export REACT_APP_STREAMING_API_URL="https://your-domain.com/api/streaming"
export REACT_APP_ADMIN_API_URL="https://your-domain.com/api/admin"
export REACT_APP_CHAT_API_URL="https://your-domain.com/api/chat"
export REACT_APP_CHAT_SOCKET_URL="wss://your-domain.com"
```

### 2.4 Build and Push Docker Images

```bash
./scripts/build-and-push.sh v1.0.0
```

This script will:
1. Login to Amazon ECR
2. Build all 5 Docker images
3. Tag images with version (`v1.0.0`), commit hash, and `latest`
4. Push all images to their respective ECR repositories

### 2.5 Verify Images in ECR

```bash
aws ecr list-images --repository-name gs-streamingapp-frontend
aws ecr list-images --repository-name gs-streamingapp-auth
aws ecr list-images --repository-name gs-streamingapp-streaming
aws ecr list-images --repository-name gs-streamingapp-admin
aws ecr list-images --repository-name gs-streamingapp-chat
```

---

## 6. Step 3 — AWS Environment Setup

### 3.1 Configure AWS CLI

```bash
aws configure
# Prompts:
# AWS Access Key ID: <your-access-key>
# AWS Secret Access Key: <your-secret-key>
# Default region name: ap-south-1
# Default output format: json
```

### 3.2 Verify Configuration

```bash
aws sts get-caller-identity
# Expected output: Account ID, User ARN, User ID
```

### 3.3 Create S3 Bucket for Video Storage

```bash
aws s3 mb s3://your-streamingapp-bucket --region ap-south-1
aws s3api put-bucket-versioning \
  --bucket your-streamingapp-bucket \
  --versioning-configuration Status=Enabled
```

---

## 7. Step 4 — Jenkins CI/CD Setup

### 7.1 Jenkins Access

Use the provided Jenkins instance:
- **URL**: https://jenkinsacademics.herovired.com/
- **Username**: `herovired`
- **Password**: `herovired`

> Or install Jenkins on your own EC2 instance (see below).

### 7.2 (Optional) Install Jenkins on EC2

```bash
# SSH into EC2 instance (Ubuntu 22.04, t3.medium recommended)
ssh -i your-key.pem ubuntu@<ec2-ip>

# Install Java
sudo apt update
sudo apt install -y openjdk-11-jdk

# Add Jenkins repo and install
wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -
sudo sh -c 'echo deb https://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
sudo apt update && sudo apt install -y jenkins

# Start Jenkins
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Get the initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Access Jenkins at `http://<ec2-ip>:8080` and complete the setup wizard.

### 7.3 Install Required Plugins

Go to **Manage Jenkins → Plugin Manager → Available** and install:

- Docker Pipeline
- Amazon ECR
- AWS Steps
- Pipeline AWS
- Kubernetes
- Slack Notification *(for ChatOps bonus)*

### 7.4 Add Credentials

Go to **Manage Jenkins → Credentials → System → Global credentials → Add Credentials**:

| Credential ID | Kind | Value |
|---|---|---|
| `aws-credentials` | AWS Credentials | Your AWS Access Key ID + Secret Access Key |
| `aws-account-id` | Secret text | Your 12-digit AWS Account ID |
| `sns-topic-arn` | Secret text | Your SNS Topic ARN (created in Step 9) |

### 7.5 Create the Pipeline Job

1. Click **New Item** → enter name `StreamingApp-CI-CD` → select **Pipeline** → OK
2. Under **General**: add a description
3. Under **Build Triggers**: check `GitHub hook trigger for GITScm polling`
4. Under **Pipeline**:
   - Definition: `Pipeline script from SCM`
   - SCM: `Git`
   - Repository URL: `https://github.com/YOUR_USERNAME/StreamingApp.git`
   - Credentials: add your GitHub credentials
   - Branch Specifier: `*/main`
   - Script Path: `Jenkinsfile`
5. Click **Save** → **Build Now**

The `Jenkinsfile` stages:
- **Checkout** — Pulls code from GitHub + sends SNS notification
- **Pre-build Validation** — Verifies Docker and AWS CLI
- **Run Tests** — Frontend and backend tests (parallel)
- **Login to ECR** — Authenticates with Amazon ECR
- **Build Images** — Builds all 5 Docker images
- **Push to ECR** — Pushes images with build number tag
- **Deploy to EKS** — Deploys via Helm (optional)

### 7.6 Configure GitHub Webhook

In your GitHub fork: **Settings → Webhooks → Add webhook**

| Field | Value |
|---|---|
| Payload URL | `http://your-jenkins-url/github-webhook/` |
| Content type | `application/json` |
| Which events | Just the `push` event |
| Active | ✓ checked |

---

## 8. Step 5 — Kubernetes Deployment (EKS)

### 8.1 Create EKS Cluster

```bash
./scripts/create-eks-cluster.sh
```

This script (~15–20 minutes) provisions:
- VPC and subnets
- EKS control plane (`streamingapp-cluster`)
- Managed node group
- AWS Load Balancer Controller
- EBS CSI Driver
- Metrics Server
- Namespaces: `dev`, `staging`, `production`

### 8.2 Configure kubectl

```bash
aws eks update-kubeconfig --name streamingapp-cluster --region ap-south-1
kubectl get nodes   # verify cluster is accessible
```

### 8.3 Configure Helm Values

Edit `k8s/helm/streamingapp/values.yaml`:

```yaml
imageRegistry:
  url: "<your-account-id>.dkr.ecr.ap-south-1.amazonaws.com"

imageTag: "v1.0.0"

secrets:
  jwtSecret: "your-strong-jwt-secret"
  awsAccessKeyId: "your-aws-access-key"
  awsSecretAccessKey: "your-aws-secret-key"
  awsS3Bucket: "your-s3-bucket-name"
  awsCdnUrl: "https://your-cloudfront-url.com"

ingress:
  enabled: true
  hosts:
    - host: streamingapp.yourdomain.com
```

### 8.4 Deploy Application

```bash
# Deploy to dev environment
./scripts/deploy-to-eks.sh dev v1.0.0

# Watch pods come up
kubectl get pods -n dev -w

# Get the frontend public URL
kubectl get svc -n dev streamingapp-frontend
```

Or deploy manually with Helm:

```bash
helm upgrade --install streamingapp ./k8s/helm/streamingapp \
  --namespace dev \
  --create-namespace \
  --set imageRegistry.url="<account-id>.dkr.ecr.ap-south-1.amazonaws.com" \
  --set imageTag="v1.0.0" \
  --set secrets.jwtSecret="your-secret"
```

### 8.5 Verify Deployment

```bash
kubectl get pods -n dev
kubectl get svc -n dev
kubectl get ingress -n dev
kubectl rollout status deployment -n dev
```

### 8.6 Scaling

```bash
# Manual scale
kubectl scale deployment streamingapp-streaming --replicas=3 -n dev

# Check Horizontal Pod Autoscaler
kubectl get hpa -n dev
kubectl describe hpa streamingapp-streaming -n dev
```

---

## 9. Step 6 — Monitoring and Logging

### 9.1 Deploy CloudWatch Monitoring

```bash
./scripts/setup-monitoring.sh
```

This deploys:
- CloudWatch Agent (metrics collection)
- Fluent Bit (log forwarding to CloudWatch Logs)
- CloudWatch Alarms (CPU, Memory, Error Rate, Pod Restarts)

### 9.2 CloudWatch Log Groups

| Log Group | Contents |
|---|---|
| `/aws/eks/streamingapp-cluster/application` | Application logs |
| `/aws/eks/streamingapp-cluster/cluster` | EKS cluster logs |
| `/aws/containerinsights/streamingapp-cluster/performance` | Performance metrics |

### 9.3 View Logs via CLI

```bash
# Tail application logs
aws logs tail /aws/eks/streamingapp-cluster/streamingapp --follow

# Filter for errors only
aws logs filter-log-events \
  --log-group-name /aws/eks/streamingapp-cluster/streamingapp \
  --filter-pattern "ERROR"

# Kubectl logs
kubectl logs -f deployment/streamingapp-frontend -n dev
kubectl logs -f -l app.kubernetes.io/component=streaming -n dev
```

### 9.4 View Metrics

```bash
kubectl top nodes
kubectl top pods -n dev
kubectl get events -n dev --sort-by='.lastTimestamp'
```

### 9.5 CloudWatch Alarms Configured

| Alarm | Metric | Threshold |
|---|---|---|
| High CPU | CPUUtilization | > 80% for 10 min |
| High Memory | MemoryUtilization | > 80% for 10 min |
| High Error Rate | 5XXError | > 10 errors in 5 min |
| Pod Restarts | PodRestartCount | > 3 in 15 min |

### 9.6 AWS Console — Container Insights

Navigate to: **AWS Console → CloudWatch → Container Insights** → select `streamingapp-cluster`

---

## 10. Step 7 — Documentation

All documentation is stored in the `docs/` directory:

| File | Description |
|---|---|
| `docs/DEPLOYMENT_GUIDE.md` | Full deployment guide |
| `docs/MONITORING.md` | CloudWatch monitoring setup |
| `docs/CHATOPS.md` | ChatOps integration guide |
| `docs/QUICK_REFERENCE.md` | Common commands cheat sheet |
| `docs/SUBMISSION_GUIDE.md` | Submission instructions |

To update and push documentation:

```bash
git add docs/ README.md PROJECT_SUBMISSION_README.md
git commit -m "docs: add deployment and monitoring documentation"
git push origin main
```

---

## 11. Step 8 — Final Validation

### 11.1 Verify All Pods Are Running

```bash
kubectl get pods -n dev
# All pods should show STATUS: Running
```

### 11.2 Test Service Endpoints

```bash
# Get the frontend URL
FRONTEND_URL=$(kubectl get svc streamingapp-frontend -n dev \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test frontend
curl http://$FRONTEND_URL

# Test backend health endpoints
curl http://$FRONTEND_URL/api/auth/health
curl http://$FRONTEND_URL/api/streaming/health
curl http://$FRONTEND_URL/api/admin/health
curl http://$FRONTEND_URL/api/chat/health
```

### 11.3 Manual Smoke Tests

1. Open `http://<frontend-url>` in a browser
2. **Register** a new user account
3. **Log in** with the created account
4. **Admin**: Upload a video via the Admin Dashboard (requires S3 credentials)
5. **Browse**: Verify the video appears in the Browse page
6. **Playback**: Play the uploaded video
7. **Chat**: Open the same video in two browser tabs and verify chat messages appear in real-time

### 11.4 Verify CI/CD Pipeline

1. Make a small code change and push to `main`
2. Confirm Jenkins automatically triggers a new build
3. Verify the new Docker images are pushed to ECR
4. Confirm the updated pods are deployed to EKS

---

## 12. Step 9 (Bonus) — ChatOps Integration

### 12.1 Create SNS Topics

```bash
# Topic for deployment events
aws sns create-topic --name streamingapp-deployments --region ap-south-1

# Topic for error alerts
aws sns create-topic --name streamingapp-alerts --region ap-south-1

# Topic for monitoring alerts
aws sns create-topic --name streamingapp-monitoring --region ap-south-1

# Save the ARNs displayed in output — you'll need them below
```

### 12.2 Choose Your Messaging Platform

Lambda functions are pre-built in the `lambda/` directory:

| Platform | Lambda File |
|---|---|
| Slack | `lambda/sns-to-slack.py` |
| Microsoft Teams | `lambda/sns-to-teams.py` |
| Telegram | `lambda/sns-to-telegram.py` |

### 12.3 Deploy Lambda (Slack Example)

**Create a Slack Incoming Webhook:**
1. Go to https://api.slack.com/apps → **Create New App → From scratch**
2. App Name: `StreamingApp Bot` → select your workspace
3. Features → **Incoming Webhooks** → toggle On
4. **Add New Webhook to Workspace** → select channel (e.g., `#deployments`)
5. Copy the Webhook URL: `https://hooks.slack.com/services/T.../B.../...`

**Deploy Lambda function:**
```bash
cd lambda
zip sns-to-slack.zip sns-to-slack.py

aws lambda create-function \
  --function-name sns-to-slack \
  --runtime python3.9 \
  --handler sns-to-slack.lambda_handler \
  --zip-file fileb://sns-to-slack.zip \
  --role arn:aws:iam::<account-id>:role/lambda-execution-role \
  --environment Variables={SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL}
```

**Subscribe Lambda to SNS:**
```bash
aws sns subscribe \
  --topic-arn arn:aws:sns:ap-south-1:<account-id>:streamingapp-deployments \
  --protocol lambda \
  --notification-endpoint arn:aws:lambda:ap-south-1:<account-id>:function:sns-to-slack

# Allow SNS to invoke Lambda
aws lambda add-permission \
  --function-name sns-to-slack \
  --statement-id sns-invoke \
  --action lambda:InvokeFunction \
  --principal sns.amazonaws.com \
  --source-arn arn:aws:sns:ap-south-1:<account-id>:streamingapp-deployments
```

### 12.4 Add SNS ARN to Jenkins

Go to **Manage Jenkins → Credentials** → update the `sns-topic-arn` secret with your SNS Topic ARN.

The `Jenkinsfile` will now send real-time Slack/Teams/Telegram notifications on:
- Build started
- Build succeeded
- Build failed
- Deployment completed

### 12.5 Test the Integration

```bash
aws sns publish \
  --topic-arn "arn:aws:sns:ap-south-1:<account-id>:streamingapp-deployments" \
  --subject "Test Notification" \
  --message "StreamingApp ChatOps integration is working!"
```

Verify the message appears in your Slack/Teams/Telegram channel.

---

## 13. Submission Instructions

1. Ensure all code, scripts, and documentation are committed and pushed to your fork:
   ```bash
   git add .
   git commit -m "feat: complete graded project submission"
   git push origin main
   ```

2. Copy your GitHub repository URL:
   ```
   https://github.com/YOUR_USERNAME/StreamingApp
   ```

3. Create a text file (`.txt`, `.docx`, or `.pdf`) containing:
   - Your GitHub repository URL
   - Any notes or observations

4. Upload the file on **Vlearn**

---

## Project Structure Reference

```
StreamingApp/
├── backend/
│   ├── authService/        # Auth microservice (port 3001)
│   ├── streamingService/   # Streaming microservice (port 3002)
│   ├── adminService/       # Admin microservice (port 3003)
│   └── chatService/        # Chat microservice (port 3004)
├── frontend/               # React SPA (port 3000)
├── k8s/
│   └── helm/streamingapp/  # Helm chart for EKS deployment
├── lambda/                 # SNS → Slack/Teams/Telegram functions
├── scripts/                # Automation scripts
│   ├── create-ecr-repos.sh
│   ├── build-and-push.sh
│   ├── create-eks-cluster.sh
│   ├── deploy-to-eks.sh
│   └── setup-monitoring.sh
├── docs/                   # Project documentation
├── Jenkinsfile             # CI/CD pipeline definition
├── docker-compose.yml      # Local development stack
└── README.md
```

---

## License

MIT © StreamFlix Team
