locals {
  resource_name = "${var.project_name}-${var.environment}"
  azs_name = data.aws_availability_zones.available.names
}