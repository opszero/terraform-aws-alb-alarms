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

variable "sns_topic_name" {
  type        = string
  description = "Name for the SNS topic. Override per client to avoid conflicts."
  default     = "alb-request-count-slack-alerts"
}

variable "lambda_function_name" {
  type        = string
  description = "Name for the Lambda function. Override per client to avoid conflicts."
  default     = "alb-request-count-slack-notifier"
}

variable "iam_role_name" {
  type        = string
  description = "Name for the Lambda IAM role. Override per client to avoid conflicts."
  default     = "alb-request-alert-lambda-role"
}

variable "alb_5xx_lb_names" {
  type        = set(string)
  description = "ALB names to scope 5xx alarms to. Empty set = all ALBs in the cluster."
  default     = []
}

variable "alb_exclude_names" {
  type        = set(string)
  description = "ALB names to exclude from all alarms (latency, request count, 5xx). Useful for test/temporary ALBs."
  default     = []
}

variable "request_count_threshold" {
  type        = number
  description = "RequestCount per minute threshold for low/medium/critical alarms."
  default     = 500
}

variable "latency_threshold_seconds" {
  type        = number
  description = "TargetResponseTime (seconds) threshold for latency alarm."
  default     = 1
}

variable "alb_5xx_low_threshold" {
  type        = number
  description = "5xx error count threshold for LOW alarm (per 5-minute window)."
  default     = 10
}

variable "alb_5xx_medium_threshold" {
  type        = number
  description = "5xx error count threshold for MEDIUM alarm (per 5-minute window)."
  default     = 20
}

variable "alb_5xx_high_threshold" {
  type        = number
  description = "5xx error count threshold for HIGH alarm (per 5-minute window)."
  default     = 30
}
