# terraform-aws-alb-alarms

Terraform module that provisions CloudWatch alarms for AWS Application Load Balancers and routes notifications to Slack via Lambda + SNS.

ALBs are discovered automatically using the EKS cluster tag `elbv2.k8s.aws/cluster`.

## Alarms created

| Alarm | Metric | Condition |
|---|---|---|
| Request count — LOW | RequestCount | > threshold/min in 1 of last 5 min |
| Request count — MEDIUM | RequestCount | > threshold/min in 3 of last 5 min |
| Request count — CRITICAL | RequestCount | > threshold/min in all 5 of last 5 min |
| Latency | TargetResponseTime | avg > threshold seconds for 10 min |
| 5xx — LOW | HTTPCode_Target_5XX_Count | > low_threshold in 5 min |
| 5xx — MEDIUM | HTTPCode_Target_5XX_Count | > medium_threshold in 5 min |
| 5xx — HIGH | HTTPCode_Target_5XX_Count | > high_threshold in 5 min |
| Lambda errors | Lambda Errors | > 0 in 5 min |

## Usage

```hcl
module "alb-alerts" {
  source = "git::git@github.com:opszero/terraform-aws-alb-alarms.git"

  environment_name  = local.environment_name
  ENV               = "prod"
  slack_webhook_url = var.slack_webhook_url

  # Scope 5xx alarms to specific ALBs; omit to monitor all ALBs in the cluster
  alb_5xx_lb_names = [
    "backend-prod-example-com",
    "api-prod-example-com",
  ]

  # Exclude test/temporary ALBs from all alarms
  alb_exclude_names = [
    "backend-test-example-com",
  ]
}
```

## Multi-client usage

Override the naming variables so multiple clients can share the same AWS account without resource name conflicts:

```hcl
module "alb-alerts" {
  source = "git::git@github.com:opszero/terraform-aws-alb-alarms.git"

  environment_name     = "acme"
  ENV                  = "prod"
  slack_webhook_url    = var.slack_webhook_url
  sns_topic_name       = "alb-request-count-slack-alerts-acme"
  lambda_function_name = "alb-request-count-slack-notifier-acme"
  iam_role_name        = "alb-request-alert-lambda-role-acme"
}
```

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| environment_name | EKS cluster name — used to discover ALBs via the tag `elbv2.k8s.aws/cluster` | `string` | — | yes |
| ENV | Short env label shown in Slack alerts (e.g. dev, prod) | `string` | — | yes |
| slack_webhook_url | Slack incoming-webhook URL to post ALB alerts to | `string` | — | yes |
| alb_5xx_lb_names | ALB names to scope 5xx alarms to; empty set = all ALBs in the cluster | `set(string)` | `[]` | no |
| alb_exclude_names | ALB names to exclude from all alarms (latency, request count, 5xx). Useful for test/temporary ALBs | `set(string)` | `[]` | no |
| sns_topic_name | Name for the SNS topic. Override per client to avoid conflicts | `string` | `"alb-request-count-slack-alerts"` | no |
| lambda_function_name | Name for the Lambda function. Override per client to avoid conflicts | `string` | `"alb-request-count-slack-notifier"` | no |
| iam_role_name | Name for the Lambda IAM role. Override per client to avoid conflicts | `string` | `"alb-request-alert-lambda-role"` | no |
| request_count_threshold | RequestCount per minute threshold for low/medium/critical alarms | `number` | `500` | no |
| latency_threshold_seconds | TargetResponseTime (seconds) threshold for latency alarm | `number` | `1` | no |
| alb_5xx_low_threshold | 5xx error count threshold for LOW alarm (per 5-minute window) | `number` | `10` | no |
| alb_5xx_medium_threshold | 5xx error count threshold for MEDIUM alarm (per 5-minute window) | `number` | `20` | no |
| alb_5xx_high_threshold | 5xx error count threshold for HIGH alarm (per 5-minute window) | `number` | `30` | no |

## Outputs

| Name | Description |
|---|---|
| sns_topic_arn | ARN of the SNS topic |
| lambda_arn | ARN of the Slack-notifier Lambda |
| lambda_function_name | Name of the Slack-notifier Lambda |

## Support

<a href="https://opszero.com"><img src="https://opszero.com/img/common/opsZero-Logo-Large.webp" width="300px"/></a>

[opsZero provides support](https://www.opszero.com/devops) for our modules including:

- Slack & Email support
- One on One Video Calls
- Implementation Guidance

## License

Apache 2 © [OpsZero](https://opszero.com)
