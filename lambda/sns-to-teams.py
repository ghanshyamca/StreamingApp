import json
import urllib3
import os
from datetime import datetime

http = urllib3.PoolManager()

TEAMS_WEBHOOK_URL = os.environ['TEAMS_WEBHOOK_URL']

def lambda_handler(event, context):
    """
    Lambda function to forward SNS messages to Microsoft Teams
    """
    
    try:
        # Parse SNS message
        sns_message = event['Records'][0]['Sns']
        subject = sns_message.get('Subject', 'StreamingApp Notification')
        message = sns_message['Message']
        timestamp = sns_message['Timestamp']
        
        # Determine theme color based on subject
        theme_color = "28a745"  # Green by default
        if "Failed" in subject or "Error" in subject or "❌" in subject:
            theme_color = "dc3545"  # Red for failures
        elif "Warning" in subject or "⚠️" in subject:
            theme_color = "ffc107"  # Yellow for warnings
        elif "Success" in subject or "✅" in subject:
            theme_color = "28a745"  # Green for success
        
        # Format Teams message (Adaptive Card format)
        teams_message = {
            "@type": "MessageCard",
            "@context": "https://schema.org/extensions",
            "summary": subject,
            "themeColor": theme_color,
            "title": subject,
            "sections": [
                {
                    "activityTitle": "StreamingApp Notification",
                    "activitySubtitle": timestamp,
                    "text": message,
                    "markdown": True
                }
            ],
            "potentialAction": [
                {
                    "@type": "OpenUri",
                    "name": "View in CloudWatch",
                    "targets": [
                        {
                            "os": "default",
                            "uri": "https://console.aws.amazon.com/cloudwatch"
                        }
                    ]
                }
            ]
        }
        
        # Send to Teams
        encoded_msg = json.dumps(teams_message).encode('utf-8')
        resp = http.request('POST', TEAMS_WEBHOOK_URL, body=encoded_msg,
                          headers={'Content-Type': 'application/json'})
        
        print(f"Teams response: {resp.status}")
        
        return {
            'statusCode': 200,
            'body': json.dumps('Message sent to Teams successfully')
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error sending message: {str(e)}')
        }
