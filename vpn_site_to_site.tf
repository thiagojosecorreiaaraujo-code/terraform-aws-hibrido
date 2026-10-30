# As duas VPNs IPSec do diagrama, terminando no Transit Gateway pela internet.
# Cada aws_vpn_connection cria 2 túneis (redundância da AWS).
#
# Escritórios e Filiais <-> Data Center: MPLS do provedor (fora da AWS). Como as
# duas VPNs caem no mesmo Transit Gateway, a AWS também serve de caminho de
# contingência entre eles se o MPLS cair.

locals {
  sites = {
    escritorios = {
      ip_publico = var.escritorios_ip_publico
      asn        = var.escritorios_bgp_asn
      cidrs      = var.escritorios_cidrs
      nome       = "Escritorios e Filiais"
    }
    datacenter = {
      ip_publico = var.datacenter_ip_publico
      asn        = var.datacenter_bgp_asn
      cidrs      = var.datacenter_cidrs
      nome       = "Data Center Corporativo"
    }
  }

  # pares (site, cidr) para as rotas estáticas no Transit Gateway
  rotas_estaticas = var.vpn_rota_estatica ? {
    for par in flatten([
      for site, s in local.sites : [for c in s.cidrs : { site = site, cidr = c }]
    ]) : "${par.site}|${par.cidr}" => par
  } : {}
}

resource "aws_customer_gateway" "site" {
  for_each   = local.sites
  bgp_asn    = each.value.asn
  ip_address = each.value.ip_publico
  type       = "ipsec.1"

  tags = { Name = "${var.projeto}-cgw-${each.key}", Site = each.value.nome }
}

resource "aws_vpn_connection" "site" {
  for_each            = local.sites
  customer_gateway_id = aws_customer_gateway.site[each.key].id
  transit_gateway_id  = aws_ec2_transit_gateway.principal.id
  type                = "ipsec.1"
  static_routes_only  = var.vpn_rota_estatica

  tunnel1_ike_versions                 = ["ikev2"]
  tunnel2_ike_versions                 = ["ikev2"]
  tunnel1_phase1_encryption_algorithms = ["AES256"]
  tunnel2_phase1_encryption_algorithms = ["AES256"]
  tunnel1_phase2_encryption_algorithms = ["AES256"]
  tunnel2_phase2_encryption_algorithms = ["AES256"]
  tunnel1_phase1_integrity_algorithms  = ["SHA2-256"]
  tunnel2_phase1_integrity_algorithms  = ["SHA2-256"]
  tunnel1_phase2_integrity_algorithms  = ["SHA2-256"]
  tunnel2_phase2_integrity_algorithms  = ["SHA2-256"]
  tunnel1_phase1_dh_group_numbers      = [14]
  tunnel2_phase1_dh_group_numbers      = [14]
  tunnel1_phase2_dh_group_numbers      = [14]
  tunnel2_phase2_dh_group_numbers      = [14]

  tags = { Name = "${var.projeto}-vpn-${each.key}", Site = each.value.nome }
}

# Rotas estáticas: a rede de cada site aponta para o anexo da sua VPN na
# tabela padrão do Transit Gateway (com BGP elas são propagadas sozinhas).
resource "aws_ec2_transit_gateway_route" "site" {
  for_each                       = local.rotas_estaticas
  destination_cidr_block         = each.value.cidr
  transit_gateway_attachment_id  = aws_vpn_connection.site[each.value.site].transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway.principal.association_default_route_table_id
}
