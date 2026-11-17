variable "passphrase" {
  type      = string
  sensitive = true
}
variable "platform_gitops_github_url" {
  type = string
}
variable "platform_gitops_github_pat" {
  type      = string
  sensitive = true
}