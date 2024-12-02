data aws_caller_identity "current" {}

variable "worker_name" {
  description = "Name of the worker node group"
  type        = string
}

resource "aws_ssm_parameter" "example" {
  name        = "worker"
  type        = "String"
  value       = "${var.worker_name}-${data.aws_caller_identity.current.account_id}"
}