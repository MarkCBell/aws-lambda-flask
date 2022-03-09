output "arn" {
  value       = aws_lambda_layer_version.this.arn
  description = "The Amazon Resource Name (ARN) of the Lambda layer with version."
}

output "layer_arn" {
  value       = aws_lambda_layer_version.this.layer_arn
  description = "The Amazon Resource Name (ARN) of the Lambda layer without version."
}

output "version" {
  value       = aws_lambda_layer_version.this.version
  description = "The Lamba layer version."
}

output "created_date" {
  value       = aws_lambda_layer_version.this.created_date
  description = "The date the layer was created."
}
