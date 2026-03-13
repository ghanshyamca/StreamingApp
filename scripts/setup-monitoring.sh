#!/bin/bash

# Script to configure CloudWatch monitoring for EKS cluster
# This sets up Container Insights for metrics and logging

set -e

CLUSTER_NAME="${CLUSTER_NAME:-streamingapp-cluster}"
AWS_REGION="${AWS_REGION:-ap-south-1}"

echo "========================================="
echo "Configuring CloudWatch Container Insights"
echo "========================================="
echo "Cluster: $CLUSTER_NAME"
echo "Region: $AWS_REGION"
echo ""

# Update kubeconfig
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"

# Create CloudWatch namespace
kubectl create namespace amazon-cloudwatch --dry-run=client -o yaml | kubectl apply -f -

# Create service account for CloudWatch agent
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cloudwatch-agent
  namespace: amazon-cloudwatch
EOF

# Attach CloudWatch policy to the service account
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

eksctl create iamserviceaccount \
  --name cloudwatch-agent \
  --namespace amazon-cloudwatch \
  --cluster "$CLUSTER_NAME" \
  --attach-policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy \
  --approve \
  --override-existing-serviceaccounts \
  --region "$AWS_REGION"

# Deploy CloudWatch agent
ClusterName="$CLUSTER_NAME"
RegionName="$AWS_REGION"
FluentBitHttpPort='2020'
FluentBitReadFromHead='Off'
[[ ${FluentBitReadFromHead} = 'On' ]] && FluentBitReadFromTail='Off'|| FluentBitReadFromTail='On'
[[ -z ${FluentBitHttpPort} ]] && FluentBitHttpServer='Off' || FluentBitHttpServer='On'

curl https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluent-bit-quickstart.yaml | sed 's/{{cluster_name}}/'${ClusterName}'/;s/{{region_name}}/'${RegionName}'/;s/{{http_server_toggle}}/"'${FluentBitHttpServer}'"/;s/{{http_server_port}}/"'${FluentBitHttpPort}'"/;s/{{read_from_head}}/"'${FluentBitReadFromHead}'"/;s/{{read_from_tail}}/"'${FluentBitReadFromTail}'"/' | kubectl apply -f -

echo ""
echo "✓ CloudWatch Container Insights configured"
echo ""

# Create CloudWatch Log Group for application logs
aws logs create-log-group \
  --log-group-name "/aws/eks/$CLUSTER_NAME/streamingapp" \
  --region "$AWS_REGION" 2>/dev/null || echo "Log group already exists"

echo "✓ CloudWatch Log Group created: /aws/eks/$CLUSTER_NAME/streamingapp"
echo ""

# Create CloudWatch Alarms
echo "Creating CloudWatch Alarms..."

# CPU Utilization Alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "${CLUSTER_NAME}-high-cpu" \
  --alarm-description "Alert when CPU exceeds 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --region "$AWS_REGION" || echo "Alarm configuration skipped"

# Memory Utilization Alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "${CLUSTER_NAME}-high-memory" \
  --alarm-description "Alert when Memory exceeds 80%" \
  --metric-name MemoryUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --region "$AWS_REGION" || echo "Alarm configuration skipped"

echo "✓ CloudWatch Alarms created"
echo ""

echo "========================================="
echo "Monitoring Setup Complete!"
echo "========================================="
echo ""
echo "CloudWatch Console:"
echo "  https://console.aws.amazon.com/cloudwatch/home?region=$AWS_REGION#container-insights:infrastructure/map/$CLUSTER_NAME"
echo ""
echo "To view logs:"
echo "  https://console.aws.amazon.com/cloudwatch/home?region=$AWS_REGION#logsV2:log-groups/log-group//aws/eks/$CLUSTER_NAME/streamingapp"
echo ""
echo "To view application metrics in CloudWatch, use queries like:"
echo "  STATS avg(node_cpu_utilization) by NodeName"
echo "  STATS avg(pod_cpu_utilization) by PodName"
