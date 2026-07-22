# terraform-aws-alb-alarms

Terraform module that provisions CloudWatch alarms for AWS Application Load Balancers and routes notifications to Slack via Lambda + SNS.

ALBs are discovered automatically using the EKS cluster tag `elbv2.k8s.aws/cluster`.

## Alarms created

| Alarm | Metric | Condition |
|---|---|---|
| Request count — LOW | RequestCount | > 500/min in 1 of last 5 min |
| Request count — MEDIUM | RequestCount | > 500/min in 3 of last 5 min |
| Request count — CRITICAL | RequestCount | > 500/min in all 5 of last 5 min |
| Latency | TargetResponseTime | avg > 1s for 10 min |
| 5xx — LOW | HTTPCode_Target_5XX_Count | > 10 in 5 min |
| 5xx — MEDIUM | HTTPCode_Target_5XX_Count | > 20 in 5 min |
| 5xx — HIGH | HTTPCode_Target_5XX_Count | > 30 in 5 min |
| Lambda errors | Lambda Errors | > 0 in 5 min |

## Usage

```hcl
module "alb-alerts" {
  source = "github.com/opszero/terraform-aws-alb-alarms"

  environment_name  = local.environment_name
  ENV               = "prod"
  slack_webhook_url = var.slack_webhook_url

  # Scope 5xx alarms to specific ALBs; omit to monitor all ALBs in the cluster
  alb_5xx_lb_names = [
    "backend-prod-example-com",
  ]
}
```

### Pin to a specific git ref

```hcl
source = "github.com/opszero/terraform-aws-alb-alarms?ref=v1.0.0"
```

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| environment_name | EKS cluster name (used to discover ALBs via tag) | `string` | — | yes |
| ENV | Short env label shown in Slack messages (e.g. dev, prod) | `string` | — | yes |
| slack_webhook_url | Slack incoming-webhook URL | `string` | — | yes |
| alb_5xx_lb_names | ALB names to scope 5xx alarms to; empty = all ALBs | `set(string)` | `[]` | no |

## Outputs

| Name | Description |
|---|---|
| sns_topic_arn | ARN of the SNS topic |
| lambda_arn | ARN of the Slack-notifier Lambda |
| lambda_function_name | Name of the Slack-notifier Lambda |

## License

Apache 2 © [OpsZero](https://opszero.com)
