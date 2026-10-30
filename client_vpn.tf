# Client VPN: "Usuários remotos VPN SSL" do diagrama (OpenVPN/TLS).
# Autenticação mútua por certificado. A CA, o certificado do servidor e o do
# cliente são gerados aqui (provider tls) e importados no ACM.
# ⚠️ As chaves privadas ficam no state: use backend remoto criptografado.

resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem       = tls_private_key.ca.private_key_pem
  is_ca_certificate     = true
  validity_period_hours = 87600 # 10 anos

  subject {
    common_name  = "${var.projeto}-ca"
    organization = var.projeto
  }

  allowed_uses = ["cert_signing", "crl_signing", "digital_signature"]
}

# ---- servidor
resource "tls_private_key" "servidor" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "servidor" {
  private_key_pem = tls_private_key.servidor.private_key_pem
  dns_names       = ["server.${var.client_vpn_dominio}"]

  subject {
    common_name = "server.${var.client_vpn_dominio}"
  }
}

resource "tls_locally_signed_cert" "servidor" {
  cert_request_pem      = tls_cert_request.servidor.cert_request_pem
  ca_private_key_pem    = tls_private_key.ca.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.ca.cert_pem
  validity_period_hours = 26280 # 3 anos

  allowed_uses = ["digital_signature", "key_encipherment", "server_auth"]
}

# ---- cliente (um certificado compartilhado; para um por usuário, repita o bloco)
resource "tls_private_key" "cliente" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "cliente" {
  private_key_pem = tls_private_key.cliente.private_key_pem
  dns_names       = ["client1.${var.client_vpn_dominio}"]

  subject {
    common_name = "client1.${var.client_vpn_dominio}"
  }
}

resource "tls_locally_signed_cert" "cliente" {
  cert_request_pem      = tls_cert_request.cliente.cert_request_pem
  ca_private_key_pem    = tls_private_key.ca.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.ca.cert_pem
  validity_period_hours = 26280

  allowed_uses = ["digital_signature", "key_encipherment", "client_auth"]
}

resource "aws_acm_certificate" "client_vpn_servidor" {
  private_key       = tls_private_key.servidor.private_key_pem
  certificate_body  = tls_locally_signed_cert.servidor.cert_pem
  certificate_chain = tls_self_signed_cert.ca.cert_pem

  tags = { Name = "${var.projeto}-client-vpn-servidor" }
}

resource "aws_cloudwatch_log_group" "client_vpn" {
  name              = "/aws/clientvpn/${var.projeto}"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_stream" "client_vpn" {
  name           = "conexoes"
  log_group_name = aws_cloudwatch_log_group.client_vpn.name
}

resource "aws_security_group" "client_vpn" {
  name        = "${var.projeto}-client-vpn"
  description = "Client VPN - saida dos usuarios remotos para a VPC e on-prem"
  vpc_id      = aws_vpc.principal.id

  egress {
    description = "Tudo para dentro da VPC e on-prem"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Redes on-prem via Transit Gateway"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = local.onprem_cidrs
  }

  tags = { Name = "${var.projeto}-sg-client-vpn" }
}

resource "aws_ec2_client_vpn_endpoint" "principal" {
  description            = "${var.projeto} - usuarios remotos VPN SSL"
  server_certificate_arn = aws_acm_certificate.client_vpn_servidor.arn
  client_cidr_block      = var.client_vpn_cidr
  split_tunnel           = var.client_vpn_split_tunnel
  transport_protocol     = "udp"
  vpn_port               = 443
  vpc_id                 = aws_vpc.principal.id
  security_group_ids     = [aws_security_group.client_vpn.id]
  dns_servers            = [cidrhost(var.vpc_cidr, 2)] # resolver da VPC

  # Servidor e cliente assinados pela MESMA CA: o ARN do servidor serve como
  # cadeia raiz dos clientes (documentado pela AWS).
  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = aws_acm_certificate.client_vpn_servidor.arn
  }

  connection_log_options {
    enabled               = true
    cloudwatch_log_group  = aws_cloudwatch_log_group.client_vpn.name
    cloudwatch_log_stream = aws_cloudwatch_log_stream.client_vpn.name
  }

  tags = { Name = "${var.projeto}-client-vpn" }
}

resource "aws_ec2_client_vpn_network_association" "privada" {
  count                  = var.qtd_azs
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.principal.id
  subnet_id              = aws_subnet.privada[count.index].id
}

# Autoriza os usuários remotos a alcançar a VPC e as redes on-prem.
resource "aws_ec2_client_vpn_authorization_rule" "destinos" {
  for_each               = toset(concat([var.vpc_cidr], local.onprem_cidrs))
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.principal.id
  target_network_cidr    = each.value
  authorize_all_groups   = true
  description            = "Acesso a ${each.value}"
}

# Rota da VPC é criada sozinha pela associação; as redes on-prem precisam de
# rota explícita (saem pela sub-rede associada -> tabela da VPC -> TGW).
resource "aws_ec2_client_vpn_route" "onprem" {
  for_each = {
    for par in setproduct(local.onprem_cidrs, range(var.qtd_azs)) :
    "${par[0]}|${par[1]}" => { cidr = par[0], idx = par[1] }
  }
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.principal.id
  destination_cidr_block = each.value.cidr
  target_vpc_subnet_id   = aws_subnet.privada[each.value.idx].id
  description            = "On-prem ${each.value.cidr} via TGW"

  depends_on = [aws_ec2_client_vpn_network_association.privada]
}

# Arquivo .ovpn pronto para o AWS VPN Client / OpenVPN (fica fora do git).
resource "local_sensitive_file" "cliente_ovpn" {
  filename        = "${path.module}/saida/cliente-${var.projeto}.ovpn"
  file_permission = "0600"
  content         = <<-EOT
    client
    dev tun
    proto udp
    remote ${replace(aws_ec2_client_vpn_endpoint.principal.dns_name, "*.", "")} 443
    remote-random-hostname
    resolv-retry infinite
    nobind
    remote-cert-tls server
    cipher AES-256-GCM
    verb 3
    <ca>
    ${trimspace(tls_self_signed_cert.ca.cert_pem)}
    </ca>
    <cert>
    ${trimspace(tls_locally_signed_cert.cliente.cert_pem)}
    </cert>
    <key>
    ${trimspace(tls_private_key.cliente.private_key_pem)}
    </key>
    reneg-sec 0
  EOT
}
