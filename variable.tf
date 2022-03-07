variable "region" {
    default = "us-east-1"
}

variable "route_key" {
    default = "GET /{proxy+}"
}

variable "integration_method" {
  default = "POST"
}