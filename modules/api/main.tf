
resource "aws_api_gateway_rest_api" "this" {
  name = var.name
}

resource "aws_api_gateway_method" "root" {
  rest_api_id        = aws_api_gateway_rest_api.this.id
  resource_id        = aws_api_gateway_rest_api.this.root_resource_id
  http_method        = var.method
  authorization      = "NONE"
  request_models     = {}
  request_parameters = {}
}

resource "aws_api_gateway_integration" "root" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_rest_api.this.root_resource_id
  http_method             = aws_api_gateway_method.root.http_method
  integration_http_method = "POST" # AWS lambdas can only be invoked with the POST method
  type                    = "AWS_PROXY"
  uri                     = var.lambda_arn
  request_parameters      = {}
  request_templates       = {}
}

resource "aws_api_gateway_resource" "proxy" {
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  rest_api_id = aws_api_gateway_rest_api.this.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id        = aws_api_gateway_rest_api.this.id
  resource_id        = aws_api_gateway_resource.proxy.id
  http_method        = var.method
  authorization      = "NONE"
  request_models     = {}
  request_parameters = {}
}

resource "aws_api_gateway_integration" "proxy" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.proxy.id
  http_method             = aws_api_gateway_method.proxy.http_method
  integration_http_method = "POST" # AWS lambdas can only be invoked with the POST method
  type                    = "AWS_PROXY"
  uri                     = var.lambda_arn
  request_parameters      = {}
  request_templates       = {}
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = var.stage_name
  depends_on  = [aws_api_gateway_integration.root, aws_api_gateway_integration.proxy]
}

resource "aws_lambda_permission" "this" {
  statement_id  = "AllowExecutionFromApiGateway"
  function_name = var.lambda_name
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
  depends_on    = [aws_api_gateway_deployment.this]
}
