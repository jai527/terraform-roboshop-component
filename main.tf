resource "aws_instance" "main" {
    ami = local.ami_id
    instance_type = var.instance_type
    subnet_id = local.private_subnet_id
    vpc_security_group_ids = [local.sg_id]

    tags = merge(
        {
            Name = "${var.project}-${var.environment}-${var.Component}"
        },

        local.common_tags
    )
  
}

resource "terraform_data" "main" {
  triggers_replace = [
    aws_instance.main.id
  ]

  connection {
    type     = "ssh"
    user     = "ec2-user"
    password = "DevOps321"
    host     = aws_instance.main.private_ip
  }

  # ✅ Step 1: Copy file
  provisioner "file" {
    source      = "bootstrap.sh"
    destination = "/tmp/bootstrap.sh"
  }

  # ✅ Step 2: Execute file
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/bootstrap.sh",
      "sudo sh /tmp/bootstrap.sh ${var.Component} ${var.environment} ${var.app_version}"
    ]
  }
}

 resource "aws_ec2_instance_state" "main" {
  instance_id = aws_instance.main.id
  state = "stopped"
  depends_on = [ terraform_data.main ]
  
}

resource "aws_ami_from_instance" "main_ami" {
  name               = "${var.project}-${var.environment}-${var.Component}-ami"
  source_instance_id = aws_instance.main.id

  depends_on = [aws_ec2_instance_state.main]
  

  tags = merge(
    {
      Name = "${var.project}-${var.environment}-${var.Component}-ami"
    },
    local.common_tags
  )
}

resource "aws_lb_target_group" "main" {
  name        = "${var.project}-${var.environment}-${var.Component}" 
  port        = var.port
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  deregistration_delay = 60

  health_check {
    healthy_threshold = 2
    interval = 10
    matcher = "200-299"
    path = local.health_check_path
    port = local.port_number
    protocol = "HTTP"
    timeout = 2
    unhealthy_threshold = 3
  }

}

resource "aws_launch_template" "main" {
  name = "${var.project}-${var.environment}-${var.Component}" 

  image_id = aws_ami_from_instance.main_ami.id

  # once autosaclling is less traffic it will terminate instance
  instance_initiated_shutdown_behavior = "terminate"

  instance_type = var.instance_type
  vpc_security_group_ids = [local.sg_id]

  # each time we apply terraform this version will be updated as default
  update_default_version = true

# tags for instance created by launch_template through autoscalling 
tag_specifications {
    resource_type = "instance"

    tags = merge(
        {
          Name = "${var.project}-${var.environment}-${var.Component}"
        },
        local.common_tags
      )
  }
  # tags for volume created by instance 
tag_specifications {
    resource_type = "volume"

    tags = merge(
        {
          Name = "${var.project}-${var.environment}-${var.Component}"
        },
        local.common_tags
      )
}
# tags for launch template
  tags = merge(
        {
          Name = "${var.project}-${var.environment}-${var.Component}"
        },
        local.common_tags
      )
}

resource "aws_autoscaling_group" "main" {
  name                      = "${var.project}-${var.environment}-${var.Component}"
  max_size                  = 10
  min_size                  = 2
  health_check_grace_period = 120
  health_check_type         = "ELB"
  desired_capacity          = 2
  force_delete              = false

  launch_template {
    id = aws_launch_template.main.id
    version = "$Latest"
  }

  vpc_zone_identifier       = [local.private_subnet_id]
  target_group_arns = [aws_lb_target_group.main.arn]

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["launch_template"]
  }

dynamic "tag" {
  for_each = {
    name = "${var.project}-${var.environment}-${var.Component}"
  }

  content {
    key                 = tag.key
    value               = tag.value
    propagate_at_launch = true
  }
}
} 

resource "aws_autoscaling_policy" "main" {
  name                   = "${var.project}-${var.environment}-${var.Component}"
  autoscaling_group_name = aws_autoscaling_group.main.name

  policy_type = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 70.0
  }
}

# This depends on target group
# if frontend frontend-dev-jai01.online
resource "aws_lb_listener_rule" "main" {
  listener_arn = local.alb_listener_arn
  priority     = var.rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  condition {
    host_header {
      values = [local.host_header]
    }
  }
}

resource "terraform_data" "main_delete" {
  triggers_replace = [
    aws_instance.main.id
  ]
  depends_on = [ aws_lb_listener_rule.main ]

 #its exicute in bastion 
  provisioner "local-exec" {
    command = "aws ec2 terminate-instances --instance-ids ${aws_instance.main.id}"
    
  }
  
}