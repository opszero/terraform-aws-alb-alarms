import json
import urllib3
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)
http = urllib3.PoolManager()

SEVERITY_CONFIG = {
    "critical": {"color": "#FF0000", "emoji": ":rotating_light:", "label": "CRITICAL"},
    "high":     {"color": "#FF0000", "emoji": ":rotating_light:", "label": "HIGH"},
    "medium":   {"color": "#FFA500", "emoji": ":warning:",        "label": "MEDIUM"},
    "low":      {"color": "#FFFF00", "emoji": ":information_source:", "label": "LOW"},
}


def get_severity(alarm_name):
    name_lower = alarm_name.lower()
    if "critical" in name_lower:
        return "critical"
    if "high" in name_lower:
        return "high"
    if "medium" in name_lower:
        return "medium"
    return "low"


def lambda_handler(event, context):
    logger.info(f"Received event: {json.dumps(event)}")

    webhook_url = os.environ["SLACK_WEBHOOK_URL"]
    environment = os.environ.get("ENV", "unknown")

    try:
        records = event.get("Records", [])
        if not records:
            return {"statusCode": 200, "body": "No SNS records found"}

        sns_record = records[0].get("Sns", {})
        message = json.loads(sns_record.get("Message", "{}"))

        alarm_name = message.get("AlarmName", "Unknown")
        new_state = message.get("NewStateValue", "Unknown")
        reason = message.get("NewStateReason", "No reason provided")
        alarm_description = message.get("AlarmDescription", "")

        # Extract ALB name from dimensions
        alb_name = "Unknown"
        trigger = message.get("Trigger", {})
        for dim in trigger.get("Dimensions", []):
            if dim.get("name") == "LoadBalancer":
                alb_name = dim.get("value", "Unknown")
                break

        severity = get_severity(alarm_name)
        cfg = SEVERITY_CONFIG[severity]

        is_ok = new_state == "OK"
        if is_ok:
            color = "#36a64f"
            title = f":white_check_mark: ALB Alert Resolved — {cfg['label']}"
        else:
            color = cfg["color"]
            title = f"{cfg['emoji']} ALB Alert — {cfg['label']}"

        slack_message = {
            "attachments": [
                {
                    "color": color,
                    "title": title,
                    "fields": [
                        {
                            "title": "Load Balancer",
                            "value": alb_name,
                            "short": True,
                        },
                        {
                            "title": "Environment",
                            "value": environment.upper(),
                            "short": True,
                        },
                        {
                            "title": "Alarm",
                            "value": alarm_name,
                            "short": False,
                        },
                        {
                            "title": "State",
                            "value": new_state,
                            "short": True,
                        },
                        {
                            "title": "Condition",
                            "value": alarm_description,
                            "short": False,
                        },
                        {
                            "title": "Reason",
                            "value": reason,
                            "short": False,
                        },
                    ],
                    "footer": "AWS ALB Monitor",
                }
            ]
        }

        response = http.request(
            "POST",
            webhook_url,
            body=json.dumps(slack_message),
            headers={"Content-Type": "application/json"},
        )

        logger.info(f"Slack response: {response.status}")
        return {"statusCode": response.status, "body": "Message sent to Slack"}

    except Exception as e:
        logger.error(f"Error: {str(e)}")
        return {"statusCode": 500, "body": f"Error: {str(e)}"}