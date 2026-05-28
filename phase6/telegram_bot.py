#!/usr/bin/env python3
"""
RustDesk Phase 6 - Telegram Bot Integration
Real-time alerts and commands via Telegram
"""

import os
import logging
from datetime import datetime
import asyncio
import aiohttp
from typing import Dict, Optional

logger = logging.getLogger(__name__)

class TelegramBot:
    """Telegram bot for alerts and commands"""

    def __init__(self, token: str, chat_id: str):
        """
        Initialize Telegram bot

        Args:
            token: Telegram bot token from @BotFather
            chat_id: Chat ID to send messages to
        """
        self.token = token
        self.chat_id = chat_id
        self.api_url = f"https://api.telegram.org/bot{token}"
        logger.info(f"Telegram bot initialized for chat {chat_id}")

    async def send_message(self, message: str, parse_mode: str = "HTML") -> bool:
        """Send text message to Telegram chat"""
        try:
            async with aiohttp.ClientSession() as session:
                data = {
                    'chat_id': self.chat_id,
                    'text': message,
                    'parse_mode': parse_mode
                }
                async with session.post(f"{self.api_url}/sendMessage", json=data) as resp:
                    if resp.status == 200:
                        logger.info(f"Telegram message sent successfully")
                        return True
                    else:
                        logger.error(f"Failed to send Telegram message: {resp.status}")
                        return False
        except Exception as e:
            logger.error(f"Telegram error: {e}")
            return False

    async def send_alert(self, device_id: str, severity: str, message: str) -> bool:
        """Send formatted alert"""
        severity_emoji = {
            'critical': '🔴',
            'high': '🟠',
            'medium': '🟡',
            'low': '🟢'
        }

        emoji = severity_emoji.get(severity, '⚪')
        timestamp = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')

        formatted_message = f"""
{emoji} <b>RustDesk Alert</b>

<b>Device:</b> {device_id}
<b>Severity:</b> {severity.upper()}
<b>Time:</b> {timestamp}

<b>Message:</b>
{message}

/status_{device_id} - View status
/remediate_{device_id} - Auto-fix
/acknowledge_{device_id} - Mark as handled
"""
        return await self.send_message(formatted_message)

    async def send_prediction(self, device_id: str, prediction: Dict) -> bool:
        """Send failure prediction alert"""
        message = f"""
⚠️ <b>Predictive Alert</b>

<b>Device:</b> {device_id}
<b>Issue:</b> {prediction['type']}
<b>Confidence:</b> {prediction['confidence']*100:.0f}%

<b>Current:</b> {prediction['current_value']:.1f}%
<b>Threshold:</b> {prediction['threshold']}%
<b>ETA to Failure:</b> {prediction['eta_hours']}h

<b>Action:</b> {prediction['recommendation']}
"""
        return await self.send_message(message)

    async def send_remediation_result(self, device_id: str, result: Dict) -> bool:
        """Send auto-remediation result"""
        status_emoji = "✅" if result['success'] else "❌"

        actions = "\n".join([f"• {action}" for action in result['actions_taken']])

        message = f"""
{status_emoji} <b>Auto-Remediation Result</b>

<b>Device:</b> {device_id}
<b>Issue:</b> {result['issue_type']}
<b>Status:</b> {"Success" if result['success'] else "Failed"}

<b>Actions Taken:</b>
{actions}

<b>Result:</b> {result['result_message']}
"""
        return await self.send_message(message)

    async def handle_command(self, command: str, device_id: str) -> str:
        """Handle incoming Telegram commands"""
        if command == 'status':
            return f"Status for {device_id}: Getting latest metrics..."
        elif command == 'remediate':
            return f"Starting auto-remediation for {device_id}..."
        elif command == 'acknowledge':
            return f"Alert for {device_id} acknowledged"
        else:
            return f"Unknown command: {command}"

async def main():
    """Test Telegram bot"""
    token = os.getenv('TELEGRAM_BOT_TOKEN', '')
    chat_id = os.getenv('TELEGRAM_CHAT_ID', '')

    if not token or not chat_id:
        print("ERROR: Set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID environment variables")
        print("Get your bot token from @BotFather on Telegram")
        return

    bot = TelegramBot(token, chat_id)

    # Test message
    await bot.send_message("✅ RustDesk Phase 6 AI Bot Connected!")

    # Test alert
    await bot.send_alert(
        'POS-ADDIS-001',
        'high',
        'CPU usage spiked to 95%. Checking for runaway processes...'
    )

    # Test prediction
    await bot.send_prediction(
        'POS-ADDIS-001',
        {
            'type': 'disk_failure',
            'confidence': 0.92,
            'current_value': 94.5,
            'threshold': 95,
            'eta_hours': 6,
            'recommendation': 'Clear old log files urgently'
        }
    )

if __name__ == '__main__':
    asyncio.run(main())
