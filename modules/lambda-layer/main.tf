resource "random_uuid" "id" {}

locals {
  path = "/tmp/${random_uuid.id.result}"
}

resource "null_resource" "build" {
  triggers = {
    run = filebase64sha256(var.requirements_file)
    rebuild = fileexists("${local.path}.zip")
  }

  provisioner "local-exec" {
    command = "rm -rf ${local.path}; mkdir -p ${local.path}/python; pip install --target=${local.path}/python --requirement=${var.requirements_file}"
  }
}

data "archive_file" "this" {
  type        = "zip"
  source_dir  = local.path
  output_path = "${local.path}.zip"
  depends_on  = [null_resource.build]
}

resource "aws_lambda_layer_version" "this" {
  filename                 = data.archive_file.this.output_path
  layer_name               = var.name
  source_code_hash         = data.archive_file.this.output_base64sha256
  compatible_runtimes      = var.compatible_runtimes
  compatible_architectures = []
}
