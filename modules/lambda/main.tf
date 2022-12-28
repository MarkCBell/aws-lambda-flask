
resource "random_uuid" "id" {}

resource "aws_iam_role" "this" {
  name = "${var.name}-role"
  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : "sts:AssumeRole",
          "Principal" : {
            "Service" : "lambda.amazonaws.com"
          }
        }
      ]
    }
  )
}

resource "aws_iam_policy" "this" {
  name = "${var.name}-policy"
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "logs:*"
          ],
          "Resource" : "arn:aws:logs:*:*:*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "lambda:InvokeFunction"
          ],
          "Resource" : "*"
        }
      ]
    }
  )
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}

module "requirements_layer" {
  source              = "../lambda-layer"
  name                = "${var.name}-dependencies"
  requirements_file   = var.requirements_path
  compatible_runtimes = [var.python_version]
}

locals {
  path = "/tmp/${random_uuid.id.result}"
}

resource "null_resource" "build" {
  triggers = {
    folder = sha256(join("", [for f in fileset(var.source_dir, "**"): filesha256("${var.source_dir}/${f}")]))
    rebuild = fileexists("${local.path}.zip")
  }

  provisioner "local-exec" {
    command = "rm -rf ${local.path}; mkdir -p ${local.path}; cp -r ${var.source_dir}/* ${local.path}; cp ${path.module}/../../resources/handler.py ${local.path}"
  }
}

data "archive_file" "this" {
  type        = "zip"
  source_dir  = local.path
  output_path = "${local.path}.zip"
  depends_on  = [null_resource.build]
}

resource "aws_lambda_function" "this" {
  function_name    = var.name
  filename         = data.archive_file.this.output_path
  source_code_hash = data.archive_file.this.output_base64sha256
  handler          = "handler.handler"
  role             = aws_iam_role.this.arn
  runtime          = var.python_version
  timeout          = 600
  memory_size      = 1024
  layers           = [module.requirements_layer.arn]
  environment {
    variables = {
      app_name = var.app_name
      app_file = var.app_file
    }
  }
}

resource "aws_cloudwatch_event_rule" "this" {
  name                = "${var.name}-keep-warm"
  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "this" {
  target_id = "${var.name}-KeepWarm"
  rule      = aws_cloudwatch_event_rule.this.name
  arn       = aws_lambda_function.this.arn
}

resource "aws_lambda_permission" "this" {
  statement_id  = "AllowExecutionFromCloudWatch"
  function_name = aws_lambda_function.this.function_name
  action        = "lambda:InvokeFunction"
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.this.arn
}
