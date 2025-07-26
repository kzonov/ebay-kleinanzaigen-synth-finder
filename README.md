# 🎹 OP-1 Finder: AI-Powered eBay Kleinanzeigen Monitor

An intelligent AI agent that automatically monitors eBay Kleinanzeigen for Teenage Engineering OP-1 synthesizers matching your specific criteria and sends notifications via Telegram when good deals are found. This is a DEMO project and might not work as expected in a year from now.

## 📖 Blog Post

Read the full story behind this project: **[My Dive into Agentic AI: Building a Smart Shopping Assistant with Strands](https://zonov.me/strands-ai-for-synth-hunting/)**

## 🤖 What It Does

This AI agent continuously monitors eBay Kleinanzeigen and notifies you when it finds OP-1 synthesizers that meet these criteria:

- 💰 **Price under €500**
- ✨ **Good condition** ("good", "very good", "excellent", or "like new")
- ❌ **No issues mentioned** in the description
- 📍 **Located near Berlin** (within 50km)
- ✅ **Currently available** (not sold/reserved)

The agent uses natural language processing to understand listing descriptions and evaluate quality contextually, unlike traditional web scrapers that rely on brittle CSS selectors.

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   EventBridge   │───▶│  Lambda Function │───▶│   eBay Klein.   │
│   (Schedule)    │    │  (OP-1 Finder)   │    │   (Browse)      │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │  AWS Bedrock     │
                       │  (Claude 3.5)    │
                       └──────────────────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │    Telegram      │
                       │  (Notifications) │
                       └──────────────────┘
```

## 🛠️ Technology Stack

- **🤖 AI Framework**: [Strands](https://github.com/strands-agents/sdk-python) for agent orchestration
- **🧠 AI Model**: AWS Bedrock with Claude 3.5 Sonnet
- **☁️ Infrastructure**: AWS Lambda (containerized), ECR, Secrets Manager, EventBridge
- **🏗️ IaC**: Terraform for infrastructure as code
- **📱 Notifications**: Telegram Bot API
- **🌐 Web Scraping**: BeautifulSoup4 + Requests

## 🚀 Quick Start

### 📱 Getting Telegram Credentials

#### Create a Telegram Bot

1. Message [@BotFather](https://t.me/BotFather) on Telegram
2. Send `/newbot` and follow instructions
3. Save the bot token (format: `1234567890:ABCDEFghijklmnopQRSTUVwxyz`)

#### Get Your Chat ID

1. Start a chat with your new bot
2. Send any message
3. Visit: `https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates`
4. Find your `chat.id` in the response

### Other prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- Docker
- Telegram bot token (get from [@BotFather](https://t.me/BotFather))

### 1. Clone and Setup

```bash
git clone https://github.com/kzonov/op1-finder-agent
cd op1-finder-agent
```

### 2. Configure Variables

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit `terraform/terraform.tfvars` with your values:

```hcl
aws_region = "eu-west-1"
project_name = "op1-finder"
telegram_token = "YOUR_TELEGRAM_BOT_TOKEN"
telegram_chat_id = "YOUR_TELEGRAM_CHAT_ID"
schedule_expression = "rate(2 hours)"
```

### 3. Deploy Infrastructure

```bash
cd terraform
terraform init
terraform apply
```

### 4. Test the Agent

```bash
# Invoke manually to test
aws lambda invoke \
    --function-name op1-finder \
    --payload '{}' \
    response.json

cat response.json
```

## 🔧 Configuration Options

### Schedule Expressions

Control how often the agent runs by modifying `schedule_expression`:

```hcl
# Every 2 hours (default)
schedule_expression = "rate(2 hours)"

# Every hour
schedule_expression = "rate(1 hour)"

# Every 30 minutes  
schedule_expression = "rate(30 minutes)"

# Business hours only (9 AM - 5 PM, weekdays)
schedule_expression = "cron(0 9-17 ? * 1-5 *)"
```

### Search Criteria

Modify the search criteria by editing `SYSTEM_PROMPT` in `src/handler.py`:

```python
SYSTEM_PROMPT = """
You are an OP-1 synthesizer hunting agent for eBay Kleinanzeigen.

TASK: Find Teenage Engineering OP-1 synthesizers that meet these criteria:
- Price under €500  # <-- Change this
- Condition described as "good", "very good", "excellent", or "like new"
- NO issues, defects, or problems mentioned in description
- Located within 50km of Berlin  # <-- Change location
- Currently available (not marked as sold/reserved)
...
"""
```

## 📊 Monitoring and Logs

### View Logs

```bash
# View recent logs
aws logs tail /aws/lambda/op1-finder --follow

# View logs from specific time
aws logs tail /aws/lambda/op1-finder --since 1h
```

### Monitoring Dashboard

The Lambda function includes comprehensive logging:

- 🌐 Web browsing activities
- 🤖 AI agent decision-making process  
- 📱 Notification sending
- ❌ Error handling and recovery

## 🔍 How the AI Agent Works

Unlike traditional web scrapers, this agent uses natural language understanding:

### Traditional Scraper (Brittle)
```python
# Breaks when HTML changes
price = soup.find('span', class_='price-value').text
if '€' in price and int(price.replace('€', '')) < 500:
    # Still need to manually parse condition...
```

### AI Agent (Intelligent)
```python
# Understands context and intent
agent = Agent(
    system_prompt="Find OP-1 under €500 in good condition near Berlin",
    tools=[browse_website, send_notification]
)
# Agent figures out how to search, evaluate, and notify
```

### Key Advantages

1. **🧠 Contextual Understanding**: Evaluates descriptions like "minimal wear" or "tiny scratch"
2. **🔄 Adaptive**: Automatically adjusts when websites change structure
3. **📝 Natural Language**: Configure with plain English instructions
4. **🛡️ Error Handling**: Gracefully handles edge cases and failures
5. **🔧 Extensible**: Easy to add new criteria or change behavior

## 🏗️ Development

### Local Testing

```bash
cd src
python handler.py  # Run locally with test data
```

### Code Structure

```
op1-finder-agent/
├── src/
│   ├── handler.py          # Main Lambda function
│   ├── requirements.txt    # Python dependencies
│   └── Dockerfile         # Container definition
├── terraform/
│   ├── main.tf            # Infrastructure definition
│   └── terraform.tfvars.example
├── docs/
│   └── architecture.md    # Detailed architecture docs
└── README.md
```

### Customization

1. **Different Items**: Change the search URL and criteria in `SYSTEM_PROMPT`
2. **Different Platforms**: Modify the browsing logic for other marketplaces
3. **Different Notifications**: Replace Telegram with email/Slack/Discord
4. **Advanced Filtering**: Add more sophisticated criteria or ML-based scoring

## 🚨 Troubleshooting

### Common Issues

**Agent not finding items:**
- Check the search URL is correct
- Verify the site structure hasn't changed
- Review CloudWatch logs for errors

**Notifications not working:**
- Verify Telegram bot token and chat ID
- Check Secrets Manager has correct values
- Ensure IAM permissions are correct

**Lambda timeouts:**
- Increase timeout in `terraform/main.tf`
- Check for network connectivity issues
- Review agent prompt complexity

### Debug Mode

Enable verbose logging by modifying the system prompt:

```python
SYSTEM_PROMPT = """
...
IMPORTANT: Be extremely verbose about your process:
- Log every step you take
- Explain your reasoning for each decision
- Include full details of what you find
...
"""
```

## Result

Here is an example of how the result may look like:

![Screenshot from a telegram bot](/telegram-result.png)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **[Strands](https://github.com/strands-agents/sdk-python)** for the excellent AI agent framework
- **[AWS Bedrock](https://aws.amazon.com/bedrock/)** for providing access to Claude models
- **[Teenage Engineering](https://teenage.engineering/)** for making amazing synthesizers worth hunting for! 🎵

## 📞 Support

- 🐛 [Report Issues](https://github.com/YOUR_USERNAME/op1-finder-agent/issues)
- 💬 [Discussions](https://github.com/YOUR_USERNAME/op1-finder-agent/discussions)  
- 📖 [Blog Post](LINK_TO_YOUR_BLOG_POST) for detailed background

---

*Happy hunting! May you find the perfect OP-1 at an amazing price! 🎹✨* 
