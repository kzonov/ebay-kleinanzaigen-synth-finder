import json
import logging
import os
import boto3
import requests
from bs4 import BeautifulSoup
from strands import Agent
from strands.models.bedrock import BedrockModel
from strands.tools import tool

# Set up logging
logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)

@tool
def browse_website(url: str) -> str:
    """Browse a website and return its text content.
    
    Args:
        url: The URL to browse
        
    Returns:
        The cleaned text content of the website
    """
    log.info(f"🌐 Browsing website: {url}")
    
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
    
    try:
        response = requests.get(url, headers=headers, timeout=15)
        response.raise_for_status()
        
        log.info(f"✅ HTTP {response.status_code}: Retrieved {len(response.content)} bytes")
        
        soup = BeautifulSoup(response.content, 'html.parser')
        
        # Remove script and style elements
        for script in soup(["script", "style"]):
            script.decompose()
        
        # Get clean text
        text = soup.get_text()
        lines = (line.strip() for line in text.splitlines())
        chunks = (phrase.strip() for line in lines for phrase in line.split("  "))
        text = ' '.join(chunk for chunk in chunks if chunk)
        
        # Limit length to avoid overwhelming the model
        if len(text) > 8000:
            text = text[:8000]
            log.info(f"📝 Truncated content to 8000 characters")
        
        log.info(f"🎯 Extracted {len(text)} characters of clean text")
        return text
        
    except requests.exceptions.RequestException as e:
        error_msg = f"❌ Error browsing {url}: {str(e)}"
        log.error(error_msg)
        return error_msg

@tool
def send_notification(message: str) -> str:
    """Send a notification message via Telegram.
    
    Args:
        message: The message to send
        
    Returns:
        Success confirmation
    """
    log.info("📱 Sending notification...")
    
    try:
        # Get Telegram credentials from AWS Secrets Manager
        secrets_client = boto3.client('secretsmanager')
        secrets_arn = os.environ.get('SECRETS_ARN')
        
        if not secrets_arn:
            return "❌ No SECRETS_ARN environment variable found"
        
        secret = secrets_client.get_secret_value(SecretId=secrets_arn)
        credentials = json.loads(secret['SecretString'])
        
        # Send via Telegram
        telegram_url = f"https://api.telegram.org/bot{credentials['TELEGRAM_TOKEN']}/sendMessage"
        payload = {
            'chat_id': credentials['TELEGRAM_CHAT_ID'],
            'text': message,
            'parse_mode': 'Markdown',
            'disable_web_page_preview': False
        }
        
        response = requests.post(telegram_url, json=payload, timeout=10)
        response.raise_for_status()
        
        log.info("✅ Notification sent successfully")
        return "Notification sent successfully"
        
    except Exception as e:
        error_msg = f"❌ Error sending notification: {str(e)}"
        log.error(error_msg)
        return error_msg

# System prompt with clear instructions
SYSTEM_PROMPT = """
You are an OP-1 synthesizer hunting agent for eBay Kleinanzeigen.

TASK: Find Teenage Engineering OP-1 synthesizers that meet these criteria:
- Price under €600
- Condition described as "good", "very good", "excellent", or "like new"
- NO issues, defects, or problems mentioned in description
- Located within 50km of Berlin (PLZ 10000-14999 or nearby cities like Potsdam, Brandenburg)
- Currently available (not marked as sold/reserved)

PROCESS:
1. Browse https://www.ebay-kleinanzeigen.de/s-musik/berlin/teenage+engineering+op-1/k0c74l3331
2. For each listing that seems promising:
   - Check the individual listing page for full details
   - Evaluate against all criteria carefully
   - If it matches, send notification with:
     * Title and brief description
     * Price and condition
     * Location
     * Direct link to listing
     * Reason why it matches criteria

Be thorough but only notify for genuine matches to avoid spam. Check not more than 5 listings.

IMPORTANT: Be verbose about your process. Log what you're doing:
- "Browsing search results page..."
- "Found X listings, checking each one..."
- "Checking listing: {title}..."
- "This listing matches/doesn't match because..."

TOOLS AVAILABLE:
- browse_website (web browsing)
- send_notification (alert when good deal found)
"""

def lambda_handler(event, context):
    """AWS Lambda handler for OP-1 finder agent."""
    
    log.info("🎹 Starting OP-1 finder agent...")
    
    try:
        # Create the AI model
        model = BedrockModel(
            model_id="eu.anthropic.claude-3-7-sonnet-20250219-v1:0",
            streaming=False
        )
        
        # Create the agent
        agent = Agent(
            model=model,
            system_prompt=SYSTEM_PROMPT,
            tools=[browse_website, send_notification]
        )
        
        # Run the agent
        log.info("🤖 Invoking agent to search for OP-1 deals...")
        result = agent("Check eBay Kleinanzeigen for OP-1 synthesizers matching my criteria")
        
        log.info(f"✅ Agent completed successfully")
        log.info(f"📊 Result: {result}")
        
        # Send success notification
        try:
            send_notification(f"✅ OP-1 Search Completed Successfully\n\nSearch finished without errors. Check logs for details about any matches found.")
        except Exception as notification_error:
            log.warning(f"Failed to send success notification: {notification_error}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'OP-1 search completed successfully',
                'result': str(result)
            })
        }
        
    except Exception as e:
        error_msg = f"❌ Error running OP-1 finder agent: {str(e)}"
        log.error(error_msg)
        
        # Try to send error notification
        try:
            send_notification(f"🚨 OP-1 Finder Error: {str(e)}")
        except:
            pass  # Don't fail if notification also fails
        
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
