provider "aws" {
  region = "us-west-2"
}

module "alb_alarms" {
  source = "./.."

  environment_name  = "my-eks-cluster-prod"
  ENV               = "prod"
  slack_webhook_url = "https://hooks.slack.com/services/XXXXXXXXX/XXXXXXXXX/XXXXXXXXXXXXXXXXXXXXXXXX"

  # Scope 5xx alarms to specific ALBs (omit to monitor all ALBs in the cluster)
  alb_5xx_lb_names = [
    "backend-prod-example-com",
    "api-prod-example-com",
  ]
}