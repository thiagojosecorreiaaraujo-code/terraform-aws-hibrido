# ---------------------------------------------------------------- geral
variable "regiao" {
  description = "Região AWS da Nuvem AWS do diagrama."
  type        = string
  default     = "sa-east-1"
}

variable "projeto" {
  description = "Prefixo dos nomes de todos os recursos."
  type        = string
  default     = "hibrido"
}

variable "tags" {
  description = "Tags extras aplicadas a todos os recursos."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------- VPC
variable "vpc_cidr" {
  description = "CIDR da VPC que hospeda EC2, RDS, Lambda e a Client VPN."
  type        = string
  default     = "10.10.0.0/16"
}

variable "qtd_azs" {
  description = "Quantidade de AZs (RDS exige no mínimo 2)."
  type        = number
  default     = 2

  validation {
    condition     = var.qtd_azs >= 2
    error_message = "O RDS exige sub-redes em pelo menos 2 AZs."
  }
}

# ---------------------------------------------------------------- Escritórios e Filiais (IPSec VPN)
variable "escritorios_ip_publico" {
  description = "IP público do roteador/firewall dos Escritórios e Filiais (ponta do túnel IPSec)."
  type        = string
}

variable "escritorios_cidrs" {
  description = "Redes internas dos Escritórios e Filiais alcançáveis pela AWS."
  type        = list(string)
  default     = ["192.168.0.0/16"]
}

variable "escritorios_bgp_asn" {
  description = "ASN do Customer Gateway dos escritórios (usado mesmo com rota estática)."
  type        = number
  default     = 65010
}

# ---------------------------------------------------------------- Data Center Corporativo (IPSec VPN)
variable "datacenter_ip_publico" {
  description = "IP público do firewall do Data Center Corporativo (ponta do túnel IPSec)."
  type        = string
}

variable "datacenter_cidrs" {
  description = "Redes internas do Data Center Corporativo (servidores e Storage Gateway)."
  type        = list(string)
  default     = ["172.16.0.0/16"]
}

variable "datacenter_bgp_asn" {
  description = "ASN do Customer Gateway do data center."
  type        = number
  default     = 65020
}

variable "vpn_rota_estatica" {
  description = "true = rotas estáticas nos túneis; false = BGP dinâmico."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------- Client VPN (usuários remotos, SSL)
variable "client_vpn_cidr" {
  description = "Pool de IPs dos usuários remotos (/22 ou maior, sem sobrepor VPC nem on-prem)."
  type        = string
  default     = "10.250.0.0/22"
}

variable "client_vpn_dominio" {
  description = "Domínio usado nos certificados da Client VPN."
  type        = string
  default     = "vpn.hibrido.internal"
}

variable "client_vpn_split_tunnel" {
  description = "true = só o tráfego para AWS/on-prem passa pela VPN."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------- EC2
variable "ec2_tipo" {
  description = "Tipo da instância EC2."
  type        = string
  default     = "t3.micro"
}

# ---------------------------------------------------------------- RDS
variable "rds_engine_versao" {
  description = "Versão do PostgreSQL."
  type        = string
  default     = "16"
}

variable "rds_classe" {
  description = "Classe da instância RDS."
  type        = string
  default     = "db.t3.micro"
}

variable "rds_storage_gb" {
  description = "Armazenamento do RDS em GB."
  type        = number
  default     = 20
}

variable "rds_multi_az" {
  description = "Habilita Multi-AZ no RDS."
  type        = bool
  default     = false
}

variable "rds_pular_snapshot_final" {
  description = "true facilita o destroy em laboratório; em produção use false."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------- Storage Gateway (VTL)
variable "storage_gateway_ip" {
  description = <<-EOT
    IP do appliance Storage Gateway (VM no hypervisor do Data Center) para ativação.
    Vazio = não ativa o gateway (a VM ainda não existe). A máquina que roda o
    terraform precisa alcançar esse IP na porta 80 (ex.: pela própria VPN).
  EOT
  type        = string
  default     = ""
}

variable "storage_gateway_fuso" {
  description = "Fuso horário do gateway."
  type        = string
  default     = "GMT-3:00"
}
