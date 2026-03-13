#!/bin/bash

# Script to setup ChatOps integration for StreamingApp
# This creates SNS topics and Lambda functions for Slack, Teams, or Telegram

set -e

AWS_REGION="${AWS_REGION:-ap-south-1}"
PLATFORM="${1:-slack}"  # slack, teams, or telegram

echo "========================================="
echo "Setting up ChatOps Integration"
echo "========================================="
echo "Platform: $PLATFORM"
echo "Region: $AWS_REGION"
echo ""

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create SNS Topics
echo "Creating SNS topics..."
DEPLOY_TOPIC_ARN=$(aws sns create-topic \
  --name streamingapp-deployments \
  --region "$AWS_REGION" \
  --query 'TopicArn' \
  --output text 2>/dev/null || \
  aws sns list-topics --region "$AWS_REGION" | \
  grep streamingapp-deployments | \
  cut -d'"' -f4)

ALERT_TOPIC_ARN=$(aws sns create-topic \
  --name streamingapp-alerts \
  --region "$AWS_REGION" \
  --query 'TopicArn' \
  --output text 2>/dev/null || \
  aws sns list-topics --region "$AWS_REGION" | \
  grep streamingapp-alerts | \
  cut -d'"' -f4)

MONITOR_TOPIC_ARN=$(aws sns create-topic \
  --name streamingapp-monitoring \
  --region "$AWS_REGION" \
  --query 'TopicArn' \
  --output text 2>/dev/null || \
  aws sns list-topics --region "$AWS_REGION" | \
  grep streamingapp-monitoring | \
  cut -d'"' -f4)

echo "✓ SNS Topics created:"
echo "  Deployments: $DEPLOY_TOPIC_ARN"
echo "  Alerts: $ALERT_TOPIC_ARN"
echo "  Monitoring: $MONITOR_TOPIC_ARN"
echo ""

# Create IAM role for Lambda
echo "Creating IAM role for Lambda..."
ROLE_NAME="StreamingAppLambdaSNSRole"

aws iam create-role \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "lambda.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }' 2>/dev/null || echo "Role already exists"

# Attach policies
aws iam attach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true

echo "✓ IAM role created"
echo ""

# Wait for role to be available
echo "Waiting for IAM role to be available..."
sleep 10

# Setup based on platform
case "$PLATFORM" in
  slack)
    echo "========================================="
    echo "Slack Integration Setup"
    echo "========================================="
    
    read -p "Enter your Slack Webhook URL: " SLACK_WEBHOOK_URL
    
    if [ -z "$SLACK_WEBHOOK_URL" ]; then
      echo "Error: Slack Webhook URL is required"
      exit 1
    fi
    
    # Create Lambda deployment package
    cd lambda
    zip sns-to-slack.zip sns-to-slack.py
    cd ..
    
    # Create Lambda function
    aws lambda create-function \
      --function-name streamingapp-sns-to-slack \
      --runtime python3.9 \
      --role "arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}" \
      --handler sns-to-slack.lambda_handler \
      --zip-file fileb://lambda/sns-to-slack.zip \
      --environment "Variables={SLACK_WEBHOOK_URL=$SLACK_WEBHOOK_URL}" \
      --timeout 30 \
      --region "$AWS_REGION" 2>/dev/null || \
    aws lambda update-function-code \
      --function-name streamingapp-sns-to-slack \
      --zip-file fileb://lambda/sns-to-slack.zip \
      --region "$AWS_REGION"
    
    # Subscribe to SNS topics
    for TOPIC_ARN in "$DEPLOY_TOPIC_ARN" "$ALERT_TOPIC_ARN" "$MONITOR_TOPIC_ARN"; do
      aws sns subscribe \
        --topic-arn "$TOPIC_ARN" \
        --protocol lambda \
        --notification-endpoint "arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:streamingapp-sns-to-slack" \
        --region "$AWS_REGION" || true
    done
    
    # Grant permissions
    for TOPIC_ARN in "$DEPLOY_TOPIC_ARN" "$ALERT_TOPIC_ARN" "$MONITOR_TOPIC_ARN"; do
      aws lambda add-permission \
        --function-name streamingapp-sns-to-slack \
        --statement-id "AllowSNSInvoke-$(echo $TOPIC_ARN | md5sum | cut -c1-8)" \
        --action lambda:InvokeFunction \
        --principal sns.amazonaws.com \
        --source-arn "$TOPIC_ARN" \
        --region "$AWS_REGION" 2>/dev/null || true
    done
    
    echo "✓ Slack integration configured"
    ;;
    
  teams)
    echo "========================================="
    echo "Microsoft Teams Integration Setup"
    echo "========================================="
    
    read -p "Enter your Teams Webhook URL: " TEAMS_WEBHOOK_URL
    
    if [ -z "$TEAMS_WEBHOOK_URL" ]; then
      echo "Error: Teams Webhook URL is required"
      exit 1
    fi
    
    # Create Lambda deployment package
    cd lambda
    zip sns-to-teams.zip sns-to-teams.py
    cd ..
    
    # Create Lambda function
    aws lambda create-function \
      --function-name streamingapp-sns-to-teams \
      --runtime python3.9 \
      --role "arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}" \
      --handler sns-to-teams.lambda_handler \
      --zip-file fileb://lambda/sns-to-teams.zip \
      --environment "Variables={TEAMS_WEBHOOK_URL=$TEAMS_WEBHOOK_URL}" \
      --timeout 30 \
      --region "$AWS_REGION" 2>/dev/null || \
    aws lambda update-function-code \
      --function-name streamingapp-sns-to-teams \
      --zip-file fileb://lambda/sns-to-teams.zip \
      --region "$AWS_REGION"
    
    # Subscribe to SNS topics
    for TOPIC_ARN in "$DEPLOY_TOPIC_ARN" "$ALERT_TOPIC_ARN" "$MONITOR_TOPIC_ARN"; do
      aws sns subscribe \
        --topic-arn "$TOPIC_ARN" \
        --protocol lambda \
        --notification-endpoint "arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:streamingapp-sns-to-teams" \
        --region "$AWS_REGION" || true
    done
    
    # Grant permissions
    for TOPIC_ARN in "$DEPLOY_TOPIC_ARN" "$ALERT_TOPIC_ARN" "$MONITOR_TOPIC_ARN"; do
      aws lambda add-permission \
        --function-name streamingapp-sns-to-teams \
        --statement-id "AllowSNSInvoke-$(echo $TOPIC_ARN | md5sum | cut -c1-8)" \
        --action lambda:InvokeFunction \
        --principal sns.amazonaws.com \
        --source-arn "$TOPIC_ARN" \
        --region "$AWS_REGION" 2>/dev/null || true
    done
    
    echo "✓ Teams integration configured"
    ;;
    
  telegram)
    echo "========================================="
    echo "Telegram Integration Setup"
    echo "========================================="
    
    read -p "Enter your Telegram Bot Token: " TELEGRAM_BOT_TOKEN
    read -p "Enter your Telegram Chat ID: " TELEGRAM_CHAT_ID
    
    if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
      echo "Error: Both Bot Token and Chat ID are required"
      exit 1
    fi
    
    # Create Lambda deployment package
    cd lambda
    zip sns-to-telegram.zip sns-to-telegram.py
    cd ..
    
    # Create Lambda function
    aws lambda create-function \
      --function-name streamingapp-sns-to-telegram \
      --runtime python3.9 \
      --role "arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}" \
      --handler sns-to-telegram.lambda_handler \
      --zip-file fileb://lambda/sns-to-telegram.zip \
      --environment "Variables={TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN,TELEGRAM_CHAT_ID=$TELEGRAM_CHAT_ID}" \
      --timeout 30 \
      --region "$AWS_REGION" 2>/dev/null || \
    aws lambda update-function-code \
      --function-name streamingapp-sns-to-telegram \
      --zip-file fileb://lambda/sns-to-telegram.zip \
      --region "$AWS_REGION"
    
    # Subscribe to SNS topics
    for TOPIC_ARN in "$DEPLOY_TOPIC_ARN" "$ALERT_TOPIC_ARN" "$MONITOR_TOPIC_ARN"; do
      aws sns subscribe \
        --topic-arn "$TOPIC_ARN" \
        --protocol lambda \
        --notification-endpoint "arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:streamingapp-sns-to-telegram" \
        --region "$AWS_REGION" || true
    done
    
    # Grant permissions
    for TOPIC_ARN in "$DEPLOY_TOPIC_ARN" "$ALERT_TOPIC_ARN" "$MONITOR_TOPIC_ARN"; do
      aws lambda add-permission \
        --function-name streamingapp-sns-to-telegram \
        --statement-id "AllowSNSInvoke-$(echo $TOPIC_ARN | md5sum | cut -c1-8)" \
        --action lambda:InvokeFunction \
        --principal sns.amazonaws.com \
        --source-arn "$TOPIC_ARN" \
        --region "$AWS_REGION" 2>/dev/null || true
    done
    
    echo "✓ Telegram integration configured"
    ;;
    
  *)
    echo "Error: Unknown platform '$PLATFORM'"
    echo "Usage: $0 [slack|teams|telegram]"
    exit 1
    ;;
esac

echo ""
echo "========================================="
echo "ChatOps Setup Complete!"
echo "========================================="
echo ""
echo "Testing notification..."
aws sns publish \
  --topic-arn "$DEPLOY_TOPIC_ARN" \
  --subject "✅ ChatOps Integration Test" \
  --message "ChatOps integration for StreamingApp is now active! You should receive notifications in your $PLATFORM channel." \
  --region "$AWS_REGION"

echo ""
echo "✓ Test message sent"
echo ""
echo "SNS Topic ARNs to use in Jenkins:"
echo "  DEPLOY_TOPIC_ARN=$DEPLOY_TOPIC_ARN"
echo "  ALERT_TOPIC_ARN=$ALERT_TOPIC_ARN"
echo "  MONITOR_TOPIC_ARN=$MONITOR_TOPIC_ARN"
echo ""
echo "Add these to Jenkins credentials as 'sns-topic-arn'"
