output "sns_topic_arn" {
  description = "ARN of the SNS topic that receives ALB CloudWatch alarm notifications."
  value       = aws_sns_topic.alb_request_slack_alerts.arn
}

output "lambda_arn" {
  description = "ARN of the Slack-notifier Lambda function."
  value       = aws_lambda_function.alb_request_notifier.arn
}

output "lambda_function_name" {
  description = "Name of the Slack-notifier Lambda function."
  value       = aws_lambda_function.alb_request_notifier.function_name
}
