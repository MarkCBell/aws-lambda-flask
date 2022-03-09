
variable "project" {
  description = "The name of this project"
  type        = string
}

variable "source_dir" {
  description = "Path of folder containing the flask application"
  type        = string
}

variable "requirements_path" {
  description = "path to requirements.txt"
  type        = string
}

variable "stage" {
  type    = string
  default = "dev"
}

variable "python_version" {
  description = "The version of Python to run under, must be available locally for building the lambda layer"
  type        = string
  default     = "python3.8"
}

variable "app_name" {
  description = ""
  type        = string
  default     = "app"
}

variable "app_file" {
  description = "The name of the Python file containing the flask app (relative to source_dir)"
  type        = string
  default     = "app"
}

