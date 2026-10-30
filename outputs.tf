output "vpc_id" {
  value = aws_vpc.principal.id
}

output "transit_gateway_id" {
  value = aws_ec2_transit_gateway.principal.id
}

# ---- VPNs IPSec: o que configurar nos firewalls dos escritórios e do DC
output "vpn_tuneis" {
  description = "IPs públicos AWS dos 2 túneis de cada site."
  value = {
    for site, v in aws_vpn_connection.site : site => {
      vpn_id      = v.id
      tunel1_ip   = v.tunnel1_address
      tunel2_ip   = v.tunnel2_address
      tunel1_cidr = v.tunnel1_inside_cidr
      tunel2_cidr = v.tunnel2_inside_cidr
    }
  }
}

output "vpn_chaves_psk" {
  description = "Chaves pré-compartilhadas dos túneis (terraform output -json vpn_chaves_psk)."
  sensitive   = true
  value = {
    for site, v in aws_vpn_connection.site : site => {
      tunel1 = v.tunnel1_preshared_key
      tunel2 = v.tunnel2_preshared_key
    }
  }
}

# ---- Client VPN
output "client_vpn_endpoint_id" {
  value = aws_ec2_client_vpn_endpoint.principal.id
}

output "client_vpn_dns" {
  value = aws_ec2_client_vpn_endpoint.principal.dns_name
}

output "client_vpn_arquivo_ovpn" {
  description = "Arquivo de configuração para os usuários remotos."
  value       = local_sensitive_file.cliente_ovpn.filename
}

# ---- serviços
output "s3_bucket" {
  value = aws_s3_bucket.dados.bucket
}

output "rds_endpoint" {
  value = aws_db_instance.principal.endpoint
}

output "rds_segredo_senha" {
  description = "ARN do segredo da senha mestre no Secrets Manager."
  value       = aws_db_instance.principal.master_user_secret[0].secret_arn
}

output "lambda_nome" {
  value = aws_lambda_function.principal.function_name
}

output "ec2_ip_privado" {
  value = aws_instance.principal.private_ip
}

output "storage_gateway_arn" {
  value = try(aws_storagegateway_gateway.vtl[0].arn, "nao ativado (storage_gateway_ip vazio)")
}
