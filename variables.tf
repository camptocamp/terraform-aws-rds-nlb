variable "name" {
  description = "The name prefix used in all resources in this module"
  type        = string
}

variable "target_group_arn" {
  description = "target_group to which we will add/remove IP targets"
  type        = string
}

variable "target_db_instance_ids" {
  description = "List the db_instances ids that will trigger the lambda function"
  type        = list(string)
}

variable "target_fqdn" {
  description = "List of target fqdn to resolve to IP (db_instances.address is a good guess)"
  type        = list(string)
}

variable "remove_untracked_tg_ip" {
  description = "deregister target from TG if not matching IP was resolved"
  type        = bool
  default     = true
}

variable "dns_servers" {
  description = "The IP of the nameservers to use for DNS lookups, separated by spaces. (Optional) (Using VPC private nameserver requires `subnet_ids` and `security_group_ids`)"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "subnet_ids to attach to the lambda function (optional)"
  type        = list(string)
  default     = [""]
}

variable "security_group_ids" {
  description = "security_group_ids to attach to the lambda function (optional)"
  type        = list(string)
  default     = [""]
}

variable "cloudwatch_logs_retention_in_days" {
  description = "Specifies the number of days you want to retain log events in the specified log group. Possible values are: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, and 3653."
  type        = number
  default     = null
}

variable "sns_kms_key_id" {
  description = "KMS encryption key to use for SNS topic at-rest encrption"
  type        = string
  default     = null
}

variable "tags" {
  description = "A mapping of tags to assign to all resources"
  type        = map(string)
  default     = {}
}
