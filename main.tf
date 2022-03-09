
module "lambda" {
  source             = "./modules/lambda"
  python_version     = var.python_version
  name      = var.project
  source_dir         = var.source_dir
  requirements_path  = var.requirements_path
  app_name = var.app_name
  app_file = var.app_file
}

module "api" {
  source      = "./modules/api"
  name        = var.project
  lambda_name = module.lambda.function_name
  lambda_arn  = module.lambda.invoke_arn
  stage_name  = var.stage
}

