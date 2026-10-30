terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }

  # Estado remoto (recomendado): o state guarda as chaves privadas da Client VPN
  # e as PSKs dos túneis IPSec. Descomente e aponte para um bucket criptografado.
  # backend "s3" {
  #   bucket         = "meu-bucket-de-state"
  #   key            = "hibrido/terraform.tfstate"
  #   region         = "sa-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

provider "aws" {
  region = var.regiao

  default_tags {
    tags = merge(var.tags, {
      Projeto    = var.projeto
      Gerenciado = "terraform"
    })
  }
}

data "aws_caller_identity" "atual" {}
data "aws_availability_zones" "disponiveis" {
  state = "available"
}
