#!/bin/bash

# Script to create an EKS cluster for StreamingApp
# Prerequisites: AWS CLI, eksctl, kubectl installed

set -e

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-streamingapp-cluster}"
AWS_REGION="${AWS_REGION:-ap-south-1}"
K8S_VERSION="${K8S_VERSION:-1.31}"
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
METRICS_SERVER_MANIFEST="https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"

if ! kubectl apply -f "$METRICS_SERVER_MANIFEST"; then
  echo "Metrics Server apply failed, attempting clean reinstall..."
  kubectl delete -f "$METRICS_SERVER_MANIFEST" --ignore-not-found=true
  kubectl apply -f "$METRICS_SERVER_MANIFEST"
fi

kubectl rollout status deployment/metrics-server -n kube-system --timeout=180s
echo "✓ Metrics Server installed"
echo ""

# Install EBS CSI Driver
echo "========================================="
echo "Installing EBS CSI Driver"
echo "========================================="
EBS_CSI_ROLE_NAME="AmazonEKS_EBS_CSI_DriverRole"
EBS_CSI_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${EBS_CSI_ROLE_NAME}"
CLUSTER_OIDC_PROVIDER=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" --query 'cluster.identity.oidc.issuer' --output text | sed 's#^https://##')
EXISTING_ROLE_PROVIDER=$(aws iam get-role --role-name "$EBS_CSI_ROLE_NAME" --query 'Role.AssumeRolePolicyDocument.Statement[0].Principal.Federated' --output text 2>/dev/null | awk -F'oidc-provider/' '{print $2}')

# Recreate role when it targets an old cluster OIDC provider.
if aws iam get-role --role-name "$EBS_CSI_ROLE_NAME" >/dev/null 2>&1 && [ -n "$EXISTING_ROLE_PROVIDER" ] && [ "$EXISTING_ROLE_PROVIDER" != "$CLUSTER_OIDC_PROVIDER" ]; then
  echo "Detected stale OIDC trust on $EBS_CSI_ROLE_NAME, recreating role..."
  for POLICY_ARN in $(aws iam list-attached-role-policies --role-name "$EBS_CSI_ROLE_NAME" --query 'AttachedPolicies[].PolicyArn' --output text); do
    aws iam detach-role-policy --role-name "$EBS_CSI_ROLE_NAME" --policy-arn "$POLICY_ARN"
  done
  aws iam delete-role --role-name "$EBS_CSI_ROLE_NAME"
fi

if ! aws iam get-role --role-name "$EBS_CSI_ROLE_NAME" >/dev/null 2>&1; then
  cat > ebs_csi_trust_policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/${CLUSTER_OIDC_PROVIDER}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${CLUSTER_OIDC_PROVIDER}:aud": "sts.amazonaws.com",
          "${CLUSTER_OIDC_PROVIDER}:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }
  ]
}
EOF

  aws iam create-role --role-name "$EBS_CSI_ROLE_NAME" --assume-role-policy-document file://ebs_csi_trust_policy.json >/dev/null
  echo "Created IAM role $EBS_CSI_ROLE_NAME"
else
  echo "IAM role $EBS_CSI_ROLE_NAME already exists"
fi

if ! aws iam list-attached-role-policies --role-name "$EBS_CSI_ROLE_NAME" --query 'AttachedPolicies[].PolicyArn' --output text | grep -q 'AmazonEBSCSIDriverPolicy'; then
  aws iam attach-role-policy --role-name "$EBS_CSI_ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy
fi

if ! eksctl get addon --cluster "$CLUSTER_NAME" --region "$AWS_REGION" --name aws-ebs-csi-driver >/dev/null 2>&1; then
  eksctl create addon \
    --name aws-ebs-csi-driver \
    --cluster "$CLUSTER_NAME" \
    --service-account-role-arn "$EBS_CSI_ROLE_ARN" \
    --region "$AWS_REGION" \
    --force
else
  CURRENT_EBS_ROLE_ARN=$(aws eks describe-addon --cluster-name "$CLUSTER_NAME" --region "$AWS_REGION" --addon-name aws-ebs-csi-driver --query 'addon.serviceAccountRoleArn' --output text)
  if [ "$CURRENT_EBS_ROLE_ARN" != "$EBS_CSI_ROLE_ARN" ]; then
    echo "Updating aws-ebs-csi-driver addon with IAM role $EBS_CSI_ROLE_ARN"
    eksctl update addon \
      --name aws-ebs-csi-driver \
      --cluster "$CLUSTER_NAME" \
      --service-account-role-arn "$EBS_CSI_ROLE_ARN" \
      --region "$AWS_REGION" \
      --force
  else
    echo "Addon aws-ebs-csi-driver already installed"
  fi
fi

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
rm -f ebs_csi_trust_policy.json

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
