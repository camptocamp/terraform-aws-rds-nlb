locals {

####################################
# Variables common to all instances:

  engine                    = "postgres"
  major_engine_version      = "12"
  initial_allocated_storage = 5
  max_allocated_storage     = 15
  port                      = "5432"
  cw_logs_retention_in_days = 731

  tags = {
    Environment = "lab"
    cluster     = "exampledb"
  }

####################################
# Variables specific to master:

  master_instance_class  = "db.t3.small"

####################################
# Variables specific to replica:

  replica_instance_class = "db.t3.micro"
}

provider "aws" {
}

###########
# Master DB
###########
module "master" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 2.0"

  identifier = "exampledb-master-postgres"

  engine                = local.engine
  engine_version        = local.major_engine_version
  major_engine_version  = local.major_engine_version
  instance_class        = local.master_instance_class
  allocated_storage     = local.initial_allocated_storage
  max_allocated_storage = local.max_allocated_storage

  name     = "postgres"
  username = "postgres"
  password = "superSecretPassword"
  port     = local.port

  vpc_security_group_ids = [data.aws_security_group.default.id]

  # DB subnet group
  subnet_ids = data.aws_subnet_ids.private.ids

  family                    = "postgres12"
  parameter_group_name      = "rds-exampledb-master"
  create_db_parameter_group = false

  tags = local.tags
}


############
# Replica DB
############
module "replica" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 2.0"

  count = 3

  identifier = "exampledb-replica-postgres-${count.index}"

  # Source database. For cross-region use this_db_instance_arn
  replicate_source_db = module.master.this_db_instance_id

  engine                = local.engine
  engine_version        = local.major_engine_version
  major_engine_version  = local.major_engine_version
  instance_class        = local.replica_instance_class
  allocated_storage     = local.initial_allocated_storage
  max_allocated_storage = local.max_allocated_storage

  # Username and password must not be set for replicas
  username = ""
  password = ""
  port     = local.port

  vpc_security_group_ids = [data.aws_security_group.default.id]

  # disable backups to create DB faster
  backup_retention_period = 0

  # Not allowed to specify a subnet group for replicas in the same region
  create_db_subnet_group = false

  family                    = "postgres12"
  parameter_group_name      = "rds-exampledb-replica"
  create_db_parameter_group = false

  tags = local.tags

  timeouts = {
    create = "24h"
    update = "80m"
    delete = "40m"
  }
}

resource "aws_lb" "rds_example" {
  name               = "rds-example"
  internal           = true
  load_balancer_type = "network"
  subnets            = data.aws_subnet_ids.private.ids
  tags = {
    Name      = "rds-example"
    line      = "lab"
    tiers     = "internal"
    rds-exampledb = "lab"
  }
}

# Listeners
###########
resource "aws_lb_listener" "rds_example" {
  load_balancer_arn = aws_lb.rds_example.arn
  port              = "5432"
  protocol          = "TCP"
  default_action {
    target_group_arn = aws_lb_target_group.rds_example.arn
    type             = "forward"
  }
}

# default target group
######################
resource "aws_lb_target_group" "rds_example" {
  name        = "rds-example"
  port        = "5432"
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = data.aws_vpc.default.id
  tags = local.tags
}

## # backends
## ####################################
# using 3 RDS replica behing the NLB
# This module can be used in place of a static aws_lb_target_group_attachment here.

module "lambda_update_nlb_example" {
  source             = "git::ssh://git@github.com/example/terraform-aws-rds-nlb.git?ref=main"

  name               = "update-rds-nlb-example"
  target_group_arn   = aws_lb_target_group.rds_example.arn
  ## use public DNS server (module untested with this):
  dns_servers        = "1.1.1.1"
  ## or use the one from a VPC:
  #dns_servers        = "10.0.0.2"
  #subnet_ids         = data.aws_subnet_ids.private.ids
  #security_group_ids = [data.aws_security_group.default.id]

  target_db_instance_ids  = [
    module.replica[0].this_db_instance_id,
    module.replica[1].this_db_instance_id
    module.replica[2].this_db_instance_id
  ]

  target_fqdn = [
    module.replica[0].this_db_instance_address,
    module.replica[1].this_db_instance_address
    module.replica[2].this_db_instance_address
  ]

  cloudwatch_logs_retention_in_days = local.cw_logs_retention_in_days

  tags = local.tags
}
