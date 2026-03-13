import json
import urllib3
import os

http = urllib3.PoolManager()

TELEGRAM_BOT_TOKEN = os.environ['TELEGRAM_BOT_TOKEN']
TELEGRAM_CHAT_ID = os.environ['TELEGRAM_CHAT_ID']

def lambda_handler(event, context):
    """
    Lambda function to forward SNS messages to Telegram
    """
    
    try:
        # Parse SNS message
        sns_message = event['Records'][0]['Sns']
        subject = sns_message.get('Subject', 'StreamingApp Notification')
        message = sns_message['Message']
        
        # Format message with emoji and better formatting
        emoji = "ℹ️"
        if "Success" in subject or "✅" in subject:
            emoji = "✅"
        elif "Failed" in subject or "Error" in subject or "❌" in subject:
            emoji = "❌"
        elif "Warning" in subject or "⚠️" in subject:
            emoji = "⚠️"
        
        # Escape markdown special characters
        message_escaped = message.replace('_', '\\_').replace('*', '\\*').replace('[', '\\[').replace('`', '\\`')
        
        telegram_message = f"{emoji} *{subject}*\n\n{message_escaped}\n\n_StreamingApp_"
        
        # Send to Telegram
        url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
        payload = {
            "chat_id": TELEGRAM_CHAT_ID,
            "text": telegram_message,
            "parse_mode": "Markdown"
        }
        
        encoded_msg = json.dumps(payload).encode('utf-8')
        resp = http.request('POST', url, body=encoded_msg, 
                          headers={'Content-Type': 'application/json'})
        
        print(f"Telegram response: {resp.status}")
        
        return {
            'statusCode': 200,
            'body': json.dumps('Message sent to Telegram successfully')
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error sending message: {str(e)}')
        }
