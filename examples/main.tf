provider "aws" {
  region = "us-east-1"
}

module "alb_alarms" {
  source = "./.."

  environment_name  = "my-eks-cluster"
  ENV               = "prod"
  slack_webhook_url = "https://hooks.slack.com/services/XXXXXXXXX/XXXXXXXXX/XXXXXXXXXXXXXXXXXXXXXXXX"

  # Scope 5xx alarms to specific ALBs (omit to monitor all ALBs in the cluster)
  alb_5xx_lb_names = [
    "backend-prod-example-com",
    "api-prod-example-com",
  ]

  # Exclude test/temporary ALBs from all alarms
  alb_exclude_names = [
    "backend-test-example-com",
  ]

  # Override resource names when sharing an AWS account across multiple clients
  # sns_topic_name       = "alb-request-count-slack-alerts-myclient"
  # lambda_function_name = "alb-request-count-slack-notifier-myclient"
  # iam_role_name        = "alb-request-alert-lambda-role-myclient"

  # Tune alarm thresholds (optional — defaults shown)
  # request_count_threshold   = 500
  # latency_threshold_seconds = 1
  # alb_5xx_low_threshold     = 10
  # alb_5xx_medium_threshold  = 20
  # alb_5xx_high_threshold    = 30
}
