variable "project_id" {
  description = "The GCP project ID where resources will be created."
  type        = string
}

variable "domain_name" {
  description = "The custom domain name to use (e.g., example.com)"
  type        = string
}

variable "region" {
  description = "The region where the resources will be deployed."
  type        = string
}

variable "bufi" {
  description = "The bufi is a variable."
  type        = string
}