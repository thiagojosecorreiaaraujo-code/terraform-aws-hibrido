# Prova a topologia do diagrama com PLAN e provider AWS simulado
# (sem credenciais, nada é criado):  terraform test

mock_provider "aws" {
  override_data {
    target = data.aws_availability_zones.disponiveis
    values = { names = ["sa-east-1a", "sa-east-1b", "sa-east-1c"] }
  }
  override_data {
    target = data.aws_caller_identity.atual
    values = { account_id = "123456789012" }
  }
  override_data {
    target = data.aws_ssm_parameter.al2023
    values = { value = "ami-0123456789abcdef0" }
  }
  override_data {
    target = data.aws_iam_policy_document.lambda_assume
    values = { json = "{}" }
  }
  override_data {
    target = data.aws_iam_policy_document.lambda_s3
    values = { json = "{}" }
  }
}

variables {
  escritorios_ip_publico = "203.0.113.10"
  datacenter_ip_publico  = "198.51.100.20"
}

run "topologia_do_diagrama" {
  command = plan

  # Nuvem AWS: S3, RDS, Lambda, EC2
  assert {
    condition     = aws_s3_bucket.dados.bucket == "hibrido-dados-123456789012"
    error_message = "bucket S3 fora do padrão"
  }
  assert {
    condition     = aws_db_instance.principal.engine == "postgres" && aws_db_instance.principal.publicly_accessible == false
    error_message = "RDS tem de ser postgres e privado"
  }
  assert {
    condition     = aws_lambda_function.principal.runtime == "python3.12"
    error_message = "Lambda ausente"
  }
  assert {
    condition     = aws_instance.principal.instance_type == "t3.micro"
    error_message = "EC2 ausente"
  }

  # Duas VPNs IPSec (escritórios e data center) no Transit Gateway
  assert {
    condition     = length(aws_vpn_connection.site) == 2
    error_message = "esperadas 2 VPNs site-to-site"
  }
  assert {
    condition     = alltrue([for k in ["escritorios", "datacenter"] : contains(keys(aws_vpn_connection.site), k)])
    error_message = "faltou VPN de escritórios ou do data center"
  }
  assert {
    condition     = aws_customer_gateway.site["datacenter"].ip_address == "198.51.100.20"
    error_message = "Customer Gateway do DC com IP errado"
  }

  # Rotas on-prem: TGW recebe uma por rede; VPC manda para o TGW
  assert {
    condition     = length(aws_ec2_transit_gateway_route.site) == 2
    error_message = "esperadas 2 rotas estáticas no TGW"
  }
  assert {
    condition     = length(aws_route.para_onprem) == 2
    error_message = "VPC sem rota para o on-prem"
  }

  # Usuários remotos VPN SSL
  assert {
    condition     = aws_ec2_client_vpn_endpoint.principal.vpn_port == 443
    error_message = "Client VPN fora da 443"
  }
  assert {
    condition     = length(aws_ec2_client_vpn_authorization_rule.destinos) == 3
    error_message = "Client VPN deve autorizar VPC + 2 redes on-prem"
  }

  # Storage Gateway só é ativado com o IP do appliance
  assert {
    condition     = length(aws_storagegateway_gateway.vtl) == 0
    error_message = "gateway não deveria ativar sem IP"
  }
}

run "storage_gateway_ativado" {
  command = plan

  variables {
    storage_gateway_ip = "172.16.10.50"
  }

  assert {
    condition     = aws_storagegateway_gateway.vtl[0].gateway_type == "VTL"
    error_message = "Storage Gateway tem de ser VTL"
  }
}
