variable "name" {
  description = "The name of the REST API"
  type        = string
}

variable "stage_name" {
  description = "The stage name for the API deployment (production/staging/etc..)"
  type        = string
}

variable "method" {
  description = "The HTTP method"
  type        = string
  default     = "ANY"
}

variable "lambda_name" {
  description = "The lambda name to invoke"
  type        = string
}

variable "lambda_arn" {
  description = "The lambda arn to invoke"
  type        = string
}

