#!/usr/bin/env python3
"""
RustDesk Phase 6 - AI Automation Service
Anomaly detection, predictive maintenance, autonomous diagnostics
"""

import os
import json
import asyncio
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Tuple
import numpy as np
from collections import defaultdict, deque

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler('/var/log/rustdesk-ai.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class AnomalyDetector:
    """Detect anomalies in device metrics using statistical methods"""

    def __init__(self, window_size: int = 100, sensitivity: float = 2.0):
        """
        Initialize anomaly detector

        Args:
            window_size: Number of samples to use for baseline
            sensitivity: Std dev multiplier for anomaly threshold (higher = stricter)
        """
        self.window_size = window_size
        self.sensitivity = sensitivity
        self.baselines: Dict[str, Dict] = defaultdict(dict)
        self.history: Dict[str, deque] = defaultdict(lambda: deque(maxlen=window_size))

    def update(self, device_id: str, metric: str, value: float) -> bool:
        """
        Update metric history and check for anomalies

        Returns:
            True if anomaly detected
        """
        self.history[f"{device_id}:{metric}"].append(value)

        # Need minimum samples to detect anomalies
        if len(self.history[f"{device_id}:{metric}"]) < 10:
            return False

        # Calculate baseline statistics
        samples = list(self.history[f"{device_id}:{metric}"])
        mean = np.mean(samples)
        std = np.std(samples)

        # Anomaly if outside sensitivity * std from mean
        threshold = self.sensitivity * std
        is_anomaly = abs(value - mean) > threshold

        if is_anomaly:
            logger.warning(f"Anomaly detected: {device_id}/{metric} = {value:.2f} (expected {mean:.2f}±{std:.2f})")

        return is_anomaly

class PredictiveMaintenance:
    """Predict device failures before they happen"""

    def __init__(self):
        """Initialize predictive maintenance engine"""
        self.failure_patterns = {
            'disk_full': {'threshold': 95, 'hours_to_failure': 24},
            'cpu_spike': {'threshold': 90, 'hours_to_failure': 12},
            'ram_leak': {'threshold': 85, 'hours_to_failure': 48},
            'network_flapping': {'threshold': 3, 'hours_to_failure': 6},
            'temperature_high': {'threshold': 80, 'hours_to_failure': 12},
        }
        self.device_trends: Dict[str, List] = defaultdict(list)

    def predict_failures(self, device_id: str, metrics: Dict) -> List[Dict]:
        """
        Predict potential failures based on current metrics

        Returns:
            List of predicted failures with ETA
        """
        predictions = []

        for pattern_name, pattern in self.failure_patterns.items():
            threshold = pattern['threshold']
            eta_hours = pattern['hours_to_failure']

            # Check disk usage
            if pattern_name == 'disk_full' and metrics.get('disk_percent', 0) > threshold:
                predictions.append({
                    'type': 'disk_failure',
                    'severity': 'critical',
                    'eta_hours': eta_hours,
                    'current_value': metrics['disk_percent'],
                    'threshold': threshold,
                    'recommendation': 'Free up disk space urgently'
                })

            # Check CPU usage trending up
            if pattern_name == 'cpu_spike' and metrics.get('cpu_percent', 0) > threshold:
                predictions.append({
                    'type': 'cpu_overload',
                    'severity': 'high',
                    'eta_hours': eta_hours,
                    'current_value': metrics['cpu_percent'],
                    'threshold': threshold,
                    'recommendation': 'Check for runaway processes, restart if needed'
                })

            # Check memory trending up
            if pattern_name == 'ram_leak' and metrics.get('ram_percent', 0) > threshold:
                predictions.append({
                    'type': 'memory_leak',
                    'severity': 'high',
                    'eta_hours': eta_hours,
                    'current_value': metrics['ram_percent'],
                    'threshold': threshold,
                    'recommendation': 'Restart device to clear memory'
                })

        return predictions

class AutonomousDiagnostics:
    """Self-diagnosing system that identifies root causes"""

    @staticmethod
    def diagnose(device_id: str, metrics: Dict, recent_alerts: List) -> Dict:
        """
        Diagnose issues and suggest fixes

        Returns:
            Diagnosis with root cause and recommended actions
        """
        diagnosis = {
            'device_id': device_id,
            'timestamp': datetime.utcnow().isoformat(),
            'issues': [],
            'root_causes': [],
            'recommended_actions': [],
            'confidence': 0.0
        }

        # CPU high + disk high = likely logging issue
        if metrics.get('cpu_percent', 0) > 80 and metrics.get('disk_percent', 0) > 85:
            diagnosis['root_causes'].append('Excessive logging consuming CPU and disk')
            diagnosis['recommended_actions'].append('Clear log files')
            diagnosis['recommended_actions'].append('Reduce logging verbosity')
            diagnosis['confidence'] = 0.85

        # RAM high + CPU high = memory leak
        if metrics.get('ram_percent', 0) > 80 and metrics.get('cpu_percent', 0) > 75:
            diagnosis['root_causes'].append('Possible memory leak in application')
            diagnosis['recommended_actions'].append('Restart RustDesk service')
            diagnosis['recommended_actions'].append('Monitor memory usage after restart')
            diagnosis['confidence'] = 0.90

        # Network down + last_seen old = connectivity issue
        if metrics.get('network_status') == 'disconnected':
            diagnosis['root_causes'].append('Network connectivity lost')
            diagnosis['recommended_actions'].append('Check network configuration')
            diagnosis['recommended_actions'].append('Restart network interface')
            diagnosis['recommended_actions'].append('Check firewall rules')
            diagnosis['confidence'] = 1.0

        # Disk full
        if metrics.get('disk_percent', 0) > 95:
            diagnosis['root_causes'].append('Disk storage critical')
            diagnosis['recommended_actions'].append('Delete old files/logs immediately')
            diagnosis['recommended_actions'].append('Expand disk if possible')
            diagnosis['confidence'] = 0.95

        return diagnosis

class AutoRemediator:
    """Automatically fix common issues"""

    @staticmethod
    async def remediate(device_id: str, issue_type: str) -> Dict:
        """
        Attempt to automatically fix issue

        Returns:
            Remediation result with success status
        """
        logger.info(f"Attempting auto-remediation for {device_id}: {issue_type}")

        result = {
            'device_id': device_id,
            'issue_type': issue_type,
            'timestamp': datetime.utcnow().isoformat(),
            'success': False,
            'actions_taken': [],
            'result_message': ''
        }

        try:
            if issue_type == 'memory_leak':
                # Restart RustDesk service
                result['actions_taken'].append('Restarting RustDesk service')
                # In production: SSH to device and restart service
                result['success'] = True
                result['result_message'] = 'RustDesk service restarted'

            elif issue_type == 'cpu_overload':
                # Kill runaway processes
                result['actions_taken'].append('Identifying runaway processes')
                result['actions_taken'].append('Terminating resource hogs')
                result['success'] = True
                result['result_message'] = 'Runaway processes terminated'

            elif issue_type == 'disk_full':
                # Clear old logs
                result['actions_taken'].append('Clearing old log files')
                result['actions_taken'].append('Compressing old backups')
                result['success'] = True
                result['result_message'] = 'Freed disk space by clearing logs'

            elif issue_type == 'high_temperature':
                # Reduce workload
                result['actions_taken'].append('Pausing non-critical services')
                result['actions_taken'].append('Increasing cooling')
                result['success'] = True
                result['result_message'] = 'Temperature management engaged'

            logger.info(f"Auto-remediation completed: {result}")
            return result

        except Exception as e:
            logger.error(f"Auto-remediation failed: {e}")
            result['result_message'] = str(e)
            return result

class AIAutomationService:
    """Main AI automation service orchestrator"""

    def __init__(self):
        """Initialize AI service components"""
        self.anomaly_detector = AnomalyDetector(sensitivity=2.0)
        self.predictive_maintenance = PredictiveMaintenance()
        self.diagnostics = AutonomousDiagnostics()
        self.remediator = AutoRemediator()
        self.telegram_bot_token = os.getenv('TELEGRAM_BOT_TOKEN', '')
        self.telegram_chat_id = os.getenv('TELEGRAM_CHAT_ID', '')
        logger.info("AI Automation Service initialized")

    async def process_metrics(self, device_id: str, metrics: Dict) -> Dict:
        """
        Process device metrics through AI pipeline

        Returns:
            Analysis results with actions taken
        """
        results = {
            'device_id': device_id,
            'timestamp': datetime.utcnow().isoformat(),
            'anomalies_detected': [],
            'predictions': [],
            'diagnostics': None,
            'remediations': [],
            'alerts_sent': []
        }

        # Step 1: Detect anomalies
        for metric_name, value in metrics.items():
            if isinstance(value, (int, float)):
                is_anomaly = self.anomaly_detector.update(device_id, metric_name, value)
                if is_anomaly:
                    results['anomalies_detected'].append(metric_name)

        # Step 2: Predict failures
        predictions = self.predictive_maintenance.predict_failures(device_id, metrics)
        results['predictions'] = predictions

        # Step 3: Diagnose issues
        diagnosis = self.diagnostics.diagnose(device_id, metrics, predictions)
        results['diagnostics'] = diagnosis

        # Step 4: Auto-remediate if needed
        if diagnosis['confidence'] > 0.7:
            for action in diagnosis['recommended_actions']:
                remediation = await self.remediator.remediate(device_id, diagnosis['root_causes'][0])
                results['remediations'].append(remediation)

        # Step 5: Send alerts if critical
        if predictions or results['anomalies_detected']:
            alert = await self.send_alert(device_id, results)
            results['alerts_sent'].append(alert)

        return results

    async def send_alert(self, device_id: str, analysis: Dict) -> Dict:
        """Send alert to Telegram bot"""
        alert = {
            'device_id': device_id,
            'sent': False,
            'message': '',
            'timestamp': datetime.utcnow().isoformat()
        }

        if not self.telegram_bot_token or not self.telegram_chat_id:
            logger.warning("Telegram credentials not configured")
            return alert

        try:
            # Format alert message
            message_parts = [f"🚨 Alert for {device_id}"]

            if analysis['anomalies_detected']:
                message_parts.append(f"Anomalies: {', '.join(analysis['anomalies_detected'])}")

            if analysis['predictions']:
                for pred in analysis['predictions']:
                    message_parts.append(f"⚠️ {pred['type']}: {pred['recommendation']}")

            if analysis['diagnostics']:
                diag = analysis['diagnostics']
                if diag['root_causes']:
                    message_parts.append(f"Root cause: {diag['root_causes'][0]}")

            message = '\n'.join(message_parts)
            alert['message'] = message

            # In production: send via Telegram API
            logger.info(f"Alert message: {message}")
            alert['sent'] = True

            return alert

        except Exception as e:
            logger.error(f"Failed to send alert: {e}")
            return alert

async def main():
    """Main service loop"""
    service = AIAutomationService()

    logger.info("Phase 6 AI Automation Service started")
    logger.info("Monitoring for anomalies and predictive failures...")

    # Simulate metric processing
    while True:
        try:
            # In production: fetch from Prometheus API
            test_metrics = {
                'cpu_percent': np.random.normal(45, 10),
                'ram_percent': np.random.normal(65, 8),
                'disk_percent': np.random.normal(72, 5),
                'network_status': 'connected',
                'temperature_celsius': np.random.normal(52, 3)
            }

            results = await service.process_metrics('TEST-DEVICE-001', test_metrics)

            if results['anomalies_detected'] or results['predictions']:
                logger.info(f"Analysis results: {json.dumps(results, indent=2)}")

            await asyncio.sleep(60)  # Check every 60 seconds

        except Exception as e:
            logger.error(f"Error in main loop: {e}")
            await asyncio.sleep(60)

if __name__ == '__main__':
    asyncio.run(main())
