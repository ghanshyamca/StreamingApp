#!/bin/bash

# Script to create an EKS cluster for StreamingApp
# Prerequisites: AWS CLI, eksctl, kubectl installed

set -e

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-streamingapp-cluster}"
AWS_REGION="${AWS_REGION:-ap-south-1}"
K8S_VERSION="${K8S_VERSION:-1.28}"
NODE_TYPE="${NODE_TYPE:-t3.medium}"
MIN_NODES="${MIN_NODES:-2}"
MAX_NODES="${MAX_NODES:-10}"
DESIRED_NODES="${DESIRED_NODES:-3}"

echo "========================================="
echo "Creating EKS Cluster: $CLUSTER_NAME"
echo "========================================="
echo "Region: $AWS_REGION"
echo "Kubernetes Version: $K8S_VERSION"
echo "Node Type: $NODE_TYPE"
echo "Node Count: $MIN_NODES - $MAX_NODES (desired: $DESIRED_NODES)"
echo ""

# Create EKS cluster
eksctl create cluster \
  --name "$CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --version "$K8S_VERSION" \
  --nodegroup-name standard-workers \
  --node-type "$NODE_TYPE" \
  --nodes "$DESIRED_NODES" \
  --nodes-min "$MIN_NODES" \
  --nodes-max "$MAX_NODES" \
  --managed \
  --with-oidc \
  --ssh-access=false \
  --alb-ingress-access \
  --full-ecr-access

echo ""
echo "✓ EKS Cluster created successfully!"
echo ""

# Update kubeconfig
echo "Updating kubeconfig..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"
echo "✓ Kubeconfig updated"
echo ""

# Verify cluster
echo "Verifying cluster..."
kubectl get nodes
echo ""

# Install AWS Load Balancer Controller
echo "========================================="
echo "Installing AWS Load Balancer Controller"
echo "========================================="

# Download IAM policy
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.6.0/docs/install/iam_policy.json

# Create IAM policy
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json || echo "Policy already exists"

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create IAM role for service account
eksctl create iamserviceaccount \
  --cluster="$CLUSTER_NAME" \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::${AWS_ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve \
  --region "$AWS_REGION" || echo "Service account already exists"

# Install AWS Load Balancer Controller using Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="$CLUSTER_NAME" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller || \
helm upgrade aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="$CLUSTER_NAME" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

echo "✓ AWS Load Balancer Controller installed"
echo ""

# Install Metrics Server
echo "========================================="
echo "Installing Metrics Server"
echo "========================================="
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
echo "✓ Metrics Server installed"
echo ""

# Install EBS CSI Driver
echo "========================================="
echo "Installing EBS CSI Driver"
echo "========================================="
eksctl create iamserviceaccount \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster "$CLUSTER_NAME" \
  --role-name AmazonEKS_EBS_CSI_DriverRole \
  --role-only \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve \
  --region "$AWS_REGION" || echo "Service account already exists"

eksctl create addon \
  --name aws-ebs-csi-driver \
  --cluster "$CLUSTER_NAME" \
  --service-account-role-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/AmazonEKS_EBS_CSI_DriverRole \
  --region "$AWS_REGION" \
  --force || echo "Addon already installed"

echo "✓ EBS CSI Driver installed"
echo ""

# Create namespaces
echo "Creating namespaces..."
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace staging --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace production --dry-run=client -o yaml | kubectl apply -f -
echo "✓ Namespaces created"
echo ""

# Clean up temporary files
rm -f iam_policy.json

echo "========================================="
echo "EKS Cluster Setup Complete!"
echo "========================================="
echo ""
echo "Cluster Name: $CLUSTER_NAME"
echo "Region: $AWS_REGION"
echo ""
echo "Next Steps:"
echo "  1. Configure your ECR repositories: ./scripts/create-ecr-repos.sh"
echo "  2. Build and push images: ./scripts/build-and-push.sh"
echo "  3. Deploy application: ./scripts/deploy-to-eks.sh"
echo ""
echo "To delete the cluster later:"
echo "  eksctl delete cluster --name $CLUSTER_NAME --region $AWS_REGION"
