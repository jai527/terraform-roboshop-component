variable "project" {
    default = "roboshop"
  
}

variable "environment" {
    default = "dev"
  
}

variable "instance_type" {
    default = "t3.micro"
  
}

variable "Component" {
    type = string
  
}

variable "app_version" {
    default = "v3"
  
}

variable "port" {
    default = 8080
  
}
variable "health_check_path" {
    default = "/health"
  
}

variable "domain_name" {
    default = "jai01.online"
  
}

variable "rule_priority" {
  
}
