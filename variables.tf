variable "environment_name" {
  type        = string
  description = "EKS cluster name — used to filter ALBs via the tag elbv2.k8s.aws/cluster."
}

variable "ENV" {
  type        = string
  description = "Short environment label shown in Slack alerts (e.g. dev, prod)."
}

variable "slack_webhook_url" {
  type        = string
  description = "Slack incoming-webhook URL to post ALB alerts to."
  sensitive   = true
}

variable "alb_5xx_lb_names" {
  type        = set(string)
  description = "ALB names to scope 5xx alarms to. Empty set = all ALBs in the cluster."
  default     = []
}
