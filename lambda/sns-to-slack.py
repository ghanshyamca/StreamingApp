import json
import urllib3
import os
from datetime import datetime, timezone

http = urllib3.PoolManager()

SLACK_WEBHOOK_URL = os.environ['SLACK_WEBHOOK_URL']


def to_unix_timestamp(value):
    """Convert SNS ISO-8601 timestamps to Unix epoch seconds for Slack."""
    if not value:
        return int(datetime.now(timezone.utc).timestamp())

    try:
        # SNS uses RFC3339 like: 2026-03-13T17:11:20.987Z
        return int(datetime.fromisoformat(value.replace('Z', '+00:00')).timestamp())
    except ValueError:
        return int(datetime.now(timezone.utc).timestamp())

def lambda_handler(event, context):
    """
    Lambda function to forward SNS messages to Slack
    """
    
    try:
        # Parse SNS message
        sns_message = event['Records'][0]['Sns']
        subject = sns_message.get('Subject', 'StreamingApp Notification')
        message = sns_message['Message']
        timestamp = sns_message['Timestamp']
        
        # Determine color based on subject
        color = "#36a64f"  # Green by default
        if "Failed" in subject or "Error" in subject or "❌" in subject:
            color = "#ff0000"  # Red for failures
        elif "Warning" in subject or "⚠️" in subject:
            color = "#ff9900"  # Orange for warnings
        elif "Success" in subject or "✅" in subject:
            color = "#36a64f"  # Green for success
        
        # Format Slack message with better formatting
        slack_message = {
            "attachments": [
                {
                    "color": color,
                    "title": subject,
                    "text": message,
                    "footer": "StreamingApp",
                    "footer_icon": "https://platform.slack-edge.com/img/default_application_icon.png",
                    "ts": to_unix_timestamp(timestamp)
                }
            ]
        }
        
        # Send to Slack
        encoded_msg = json.dumps(slack_message).encode('utf-8')
        resp = http.request('POST', SLACK_WEBHOOK_URL, body=encoded_msg,
                          headers={'Content-Type': 'application/json'})
        
        print(f"Slack response: {resp.status}")
        
        return {
            'statusCode': 200,
            'body': json.dumps('Message sent to Slack successfully')
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error sending message: {str(e)}')
        }
