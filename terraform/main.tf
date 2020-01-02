provider "aws" {
  version = "1.39"
  region  = "${var.os_region}"

  assume_role {
    role_arn = "${var.os_role_arn}"
  }
}

provider "aws" {
  version = "1.39"
  alias   = "alm"
  region  = "${var.alm_region}"

  assume_role {
    role_arn = "${var.alm_role_arn}"
  }
}

data "terraform_remote_state" "env_remote_state" {
  backend   = "s3"
  workspace = "${terraform.workspace}"

  config {
    bucket   = "${var.state_bucket}"
    key      = "operating-system"
    region   = "${var.alm_region}"
    role_arn = "${var.alm_role_arn}"
  }
}

data "terraform_remote_state" "alm_remote_state" {
  backend   = "s3"
  workspace = "${var.alm_workspace}"

  config {
    bucket   = "${var.alm_state_bucket}"
    key      = "alm"
    region   = "${var.alm_region}"
    role_arn = "${var.alm_role_arn}"
  }
}

resource "local_file" "kubeconfig" {
  filename = "${path.module}/outputs/kubeconfig"
  content  = "${data.terraform_remote_state.env_remote_state.eks_cluster_kubeconfig}"
}

data "aws_secretsmanager_secret_version" "ldap_bind_password" {
  provider  = "aws.alm"
  secret_id = "${data.terraform_remote_state.alm_remote_state.bind_user_password_secret_id}"
}

resource "local_file" "helm_vars" {
  filename = "${path.module}/outputs/${terraform.workspace}.yaml"

  content = <<EOF
vault:
  persist: true

ldap:
  server: ldap.external-services
  basedn: cn=accounts,dc=internal,dc=smartcolumbusos,dc=com
  userdn: cn=users
  groupdn: cn=groups
  binduser: uid=binduser
  bindpass: "${data.aws_secretsmanager_secret_version.ldap_bind_password.secret_string}"
  userattr: uid
  groupattr: cn
  start_tls: true
  insecure_tls: true

kubernetes:
  boundServiceAccounts: reaper,andi
  boundServiceAccountNamespaces: streaming-services,admin
  tokenTtl: 2m
EOF
}

resource "null_resource" "helm_deploy" {
  provisioner "local-exec" {
    command = <<EOF
set -ex

export KUBECONFIG=${local_file.kubeconfig.filename}

export AWS_DEFAULT_REGION=us-east-2

helm repo add scdp https://smartcitiesdata.github.io/charts
helm repo update
helm upgrade --install vault scdp/vault --namespace=vault \
    --version ${var.chart_version} \
    --values ${local_file.helm_vars.filename} \
    --values ../vault.yaml \
    ${var.extra_helm_args}
EOF
  }

  triggers {
    # Triggers a list of values that, when changed, will cause the resource to be recreated
    # ${uuid()} will always be different thus always executing above local-exec
    hack_that_always_forces_null_resources_to_execute = "${uuid()}"
  }
}

variable "alm_workspace" {
  description = "The workspace to pull ALM outputs from"
  default     = "alm"
}

variable "alm_state_bucket" {
  description = "The name of the S3 state bucket for ALM"
  default     = "scos-alm-terraform-state"
}

variable "alm_region" {
  description = "Region of ALM resources"
  default     = "us-east-2"
}

variable "alm_role_arn" {
  description = "The ARN for the assume role for ALM access"
  default     = "arn:aws:iam::199837183662:role/jenkins_role"
}

variable "os_region" {
  description = "Region of OS resources"
  default     = "us-west-2"
}

variable "os_role_arn" {
  description = "The ARN for the assume role for OS access"
}

variable "state_bucket" {
  description = "The name of the S3 state bucket for ALM"
  default     = "scos-alm-terraform-state"
}

variable "extra_helm_args" {
  description = "Helm options"
  default     = ""
}

variable "chart_version" {
  description = "The version of the vault chart to deploy"
  default     = "1.0.0"
}
