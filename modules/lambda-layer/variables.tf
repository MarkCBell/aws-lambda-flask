variable "compatible_runtimes" {
  type        = list(string)
  description = "(Optional) A list of Runtimes this layer is compatible with. Up to 5 runtimes can be specified."
  default     = null
}

variable "name" {
  type        = string
  description = "(Required) A unique name for the Lambda Layer."
}

variable "requirements_file" {
  type        = string
  description = "(Required) The location of requirements.txt"
}

