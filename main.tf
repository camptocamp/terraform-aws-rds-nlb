resource "aws_sns_topic" "this" {
  name = "${var.name}-rds-events"
  tags = var.tags
}

# Subscribe RDS events from db instances and send them to the dedicated SNS topic.
#
# NB: We subscribe to many event, this list could be trimmed
#     but it doesn't do much harm to run the function too many time.
#     Not anough could be problematic.
resource "aws_db_event_subscription" "this" {
  name      = "${var.name}-rds-event-sub"
  sns_topic = aws_sns_topic.this.arn

  source_type = "db-instance"
  source_ids  = var.target_db_instance_ids

  event_categories = [
    "availability",
    "deletion",
    "failover",
    "failure",
    "maintenance",
    "notification",
    "read replica",
    "recovery",
    "restoration",
  ]
  tags = var.tags
}

# Invoke lambda function on SNS event
#
resource "aws_sns_topic_subscription" "this" {
  topic_arn = aws_sns_topic.this.arn
  protocol  = "lambda"
  endpoint  = module.lambda_function.lambda_function_arn
}

# Create Lambda function with required permissions
#
module "lambda_function" {
  source                 = "terraform-aws-modules/lambda/aws"
  version                = "~> 2.0"
  function_name          = "${var.name}-function"
  description            = "updates target-group with IP from RDS db_instance(s)"
  source_path            = "${path.module}/lambda/"
  handler                = "elb_hostname_as_target.lambda_handler"
  runtime                = "python3.7"
  timeout                = 60
  vpc_subnet_ids         = var.subnet_ids
  vpc_security_group_ids = var.security_group_ids
  attach_network_policy  = true

  create_current_version_allowed_triggers   = false
  create_unqualified_alias_allowed_triggers = true
  allowed_triggers = {
    allowFromSNS= {
      service    = "sns"
      source_arn = aws_sns_topic.this.arn
    }
  }

  attach_policy_statements = true
  policy_statements = {
   createNetIfaces = {
     effect = "Allow"
     actions = [
       "elasticloadbalancing:RegisterTargets",
       "elasticloadbalancing:DeregisterTargets",
       "elasticloadbalancing:DescribeTargetHealth",
       "ec2:CreateNetworkInterface",
       "ec2:DescribeNetworkInterfaces",
       "ec2:DeleteNetworkInterface"
     ]
     resources = [ "*" ]
   }
   writeLogs = {
     effect = "Allow"
     actions = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
     ]
     resources = ["arn:aws:logs:*:*:*"]
    }
  }

  cloudwatch_logs_retention_in_days = var.cloudwatch_logs_retention_in_days

  environment_variables = {
    TARGET_FQDNS           = join(" ", var.target_fqdn)
    ELB_TG_ARN             = var.target_group_arn
    DNS_SERVERS            = var.dns_servers
    REMOVE_UNTRACKED_TG_IP = var.remove_untracked_tg_ip
  }

  tags = var.tags
}

# You want to register your db_instances when your apply
# this module. Don't you ?
data "aws_lambda_invocation" "this" {
   function_name = module.lambda_function.lambda_function_qualified_arn

   input = <<EOJSON
 {
   "Origin": "terraform invokation of ${var.name}"
 }
EOJSON
}

