data "aws_lbs" "cluster_albs" {
  tags = {
    "elbv2.k8s.aws/cluster" = var.environment_name
  }
}

locals {
  alb_arns = toset([
    for arn in data.aws_lbs.cluster_albs.arns
    : arn if can(regex(":loadbalancer/app/", arn))
  ])

  alb_targets = length(var.alb_exclude_names) == 0 ? data.aws_lb.cluster_albs : {
    for k, v in data.aws_lb.cluster_albs : k => v if !contains(tolist(var.alb_exclude_names), v.name)
  }

  alb_5xx_targets = length(var.alb_5xx_lb_names) == 0 ? local.alb_targets : {
    for k, v in local.alb_targets : k => v if contains(tolist(var.alb_5xx_lb_names), v.name)
  }
}

data "aws_lb" "cluster_albs" {
  for_each = local.alb_arns
  arn      = each.value
}

resource "aws_sns_topic" "alb_request_slack_alerts" {
  name = "alb-request-count-slack-alerts"
}

resource "aws_iam_role" "alb_alert_lambda_role" {
  name = "alb-request-alert-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "alb_lambda_basic" {
  role       = aws_iam_role.alb_alert_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "alb_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/alb_notifier.py"
  output_path = "${path.module}/alb_lambda.zip"
}

resource "aws_lambda_function" "alb_request_notifier" {
  function_name    = "alb-request-count-slack-notifier"
  role             = aws_iam_role.alb_alert_lambda_role.arn
  handler          = "alb_notifier.lambda_handler"
  runtime          = "python3.9"
  filename         = data.archive_file.alb_lambda_zip.output_path
  source_code_hash = data.archive_file.alb_lambda_zip.output_base64sha256

  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook_url
      ENV               = var.ENV
    }
  }
}

resource "aws_sns_topic_subscription" "alb_request_lambda_sub" {
  topic_arn = aws_sns_topic.alb_request_slack_alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.alb_request_notifier.arn
}

resource "aws_lambda_permission" "alb_allow_sns" {
  statement_id  = "AllowExecutionFromSNSALB"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.alb_request_notifier.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alb_request_slack_alerts.arn
}

resource "aws_cloudwatch_metric_alarm" "alb_notifier_lambda_errors" {
  alarm_name          = "lambda-errors-${aws_lambda_function.alb_request_notifier.function_name}"
  alarm_description   = "Lambda function errors > 0 in a 5-minute window"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.alb_request_notifier.function_name
  }

  alarm_actions = [aws_sns_topic.alb_request_slack_alerts.arn]
  ok_actions    = [aws_sns_topic.alb_request_slack_alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "alb_request_low" {
  for_each = local.alb_targets

  alarm_name          = "alb-request-count-low-${each.value.name}"
  alarm_description   = "LOW: RequestCount > 500/min in 1+ of last 5 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  datapoints_to_alarm = 1
  metric_name         = "RequestCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 500
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = each.value.arn_suffix
  }

  alarm_actions = [aws_sns_topic.alb_request_slack_alerts.arn]
  ok_actions    = [aws_sns_topic.alb_request_slack_alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "alb_request_medium" {
  for_each = local.alb_targets

  alarm_name          = "alb-request-count-medium-${each.value.name}"
  alarm_description   = "MEDIUM: RequestCount > 500/min in 3+ of last 5 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  datapoints_to_alarm = 3
  metric_name         = "RequestCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 500
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = each.value.arn_suffix
  }

  alarm_actions = [aws_sns_topic.alb_request_slack_alerts.arn]
  ok_actions    = [aws_sns_topic.alb_request_slack_alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "alb_request_critical" {
  for_each = local.alb_targets

  alarm_name          = "alb-request-count-critical-${each.value.name}"
  alarm_description   = "CRITICAL: RequestCount > 500/min in all 5 of last 5 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  datapoints_to_alarm = 5
  metric_name         = "RequestCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 500
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = each.value.arn_suffix
  }

  alarm_actions = [aws_sns_topic.alb_request_slack_alerts.arn]
  ok_actions    = [aws_sns_topic.alb_request_slack_alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "alb_latency" {
  for_each = local.alb_targets

  alarm_name          = "alb-latency-${each.value.name}"
  alarm_description   = "ALB target response time exceeded 1s average for 10 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = each.value.arn_suffix
  }

  alarm_actions = [aws_sns_topic.alb_request_slack_alerts.arn]
  ok_actions    = [aws_sns_topic.alb_request_slack_alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx_low" {
  for_each = local.alb_5xx_targets

  alarm_name          = "alb-5xx-low-${each.value.name}"
  alarm_description   = "[${var.ENV}] [LOW] ${each.value.name} — 1–10 HTTP 5xx errors in 5 min."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = each.value.arn_suffix
  }

  alarm_actions = [aws_sns_topic.alb_request_slack_alerts.arn]
  ok_actions    = [aws_sns_topic.alb_request_slack_alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx_medium" {
  for_each = local.alb_5xx_targets

  alarm_name          = "alb-5xx-medium-${each.value.name}"
  alarm_description   = "[${var.ENV}] [MEDIUM] ${each.value.name} — 10–20 HTTP 5xx errors in 5 min."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 20
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = each.value.arn_suffix
  }

  alarm_actions = [aws_sns_topic.alb_request_slack_alerts.arn]
  ok_actions    = [aws_sns_topic.alb_request_slack_alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx_high" {
  for_each = local.alb_5xx_targets

  alarm_name          = "alb-5xx-high-${each.value.name}"
  alarm_description   = "[${var.ENV}] [HIGH] ${each.value.name} — 20+ HTTP 5xx errors in 5 min. Immediate action required."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 30
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = each.value.arn_suffix
  }

  alarm_actions = [aws_sns_topic.alb_request_slack_alerts.arn]
  ok_actions    = [aws_sns_topic.alb_request_slack_alerts.arn]
}
