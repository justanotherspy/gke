terraform {
  required_version = ">= 1.0.0"
  backend "gcs" {
    bucket = "justanotherspy-terraform-state"
    prefix = "dev"
  }
}
provider "null" {}

resource "null_resource" "null_resource" {
  provisioner "local-exec" {
    command = "echo ${var.my_var}"
  }
}

variable "my_var" {
  type    = string
  default = "Hello World!"
}
