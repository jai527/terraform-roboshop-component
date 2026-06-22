locals {
  ami_id = data.aws_ami.joindevops.id
  private_subnet_id = split(",",data.aws_ssm_parameter.private_subnet_id.value)[0]
  sg_id = data.aws_ssm_parameter.sg_id.value
  vpc_id = data.aws_ssm_parameter.vpc_id.value
  health_check_path = var.Component == "frontend" ? "/" : "/health"
  port_number = var.Component == "frontend" ? "80" : "8080"
  backend_alb_listener_arn = data.aws_ssm_parameter.backend_alb_listener_arn.value
  frontend_alb_listener_arn = data.aws_ssm_parameter.frontend_alb_listener_arn.value
  alb_listener_arn = var.Component == "frontend" ? local.frontend_alb_listener_arn : local.backend_alb_listener_arn
  host_header = var.Component == "frontend" ? "${var.Component}-${var.environment}.${var.domain_name}" : "${var.Component}.backend-alb-${var.environment}.${var.domain_name}"
  common_tags={
    project = var.project
    environment = var.environment
    terraform = true
  }
}