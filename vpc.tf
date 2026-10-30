# VPC "Nuvem AWS": sub-redes privadas onde ficam EC2, RDS, Lambda, o anexo do
# Transit Gateway e as associações da Client VPN. Não há Internet Gateway: o
# acesso vem só pelas VPNs (site-to-site e Client VPN).

locals {
  azs          = slice(data.aws_availability_zones.disponiveis.names, 0, var.qtd_azs)
  onprem_cidrs = concat(var.escritorios_cidrs, var.datacenter_cidrs)
  acesso_cidrs = concat([var.vpc_cidr, var.client_vpn_cidr], local.onprem_cidrs)
}

resource "aws_vpc" "principal" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.projeto}-vpc" }
}

resource "aws_subnet" "privada" {
  count             = var.qtd_azs
  vpc_id            = aws_vpc.principal.id
  availability_zone = local.azs[count.index]
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 1)

  tags = { Name = "${var.projeto}-privada-${local.azs[count.index]}" }
}

resource "aws_route_table" "privada" {
  vpc_id = aws_vpc.principal.id
  tags   = { Name = "${var.projeto}-rt-privada" }
}

resource "aws_route_table_association" "privada" {
  count          = var.qtd_azs
  subnet_id      = aws_subnet.privada[count.index].id
  route_table_id = aws_route_table.privada.id
}

# Redes dos escritórios e do data center saem da VPC pelo Transit Gateway.
resource "aws_route" "para_onprem" {
  for_each               = toset(local.onprem_cidrs)
  route_table_id         = aws_route_table.privada.id
  destination_cidr_block = each.value
  transit_gateway_id     = aws_ec2_transit_gateway.principal.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.vpc]
}

# S3 alcançável pelas sub-redes privadas sem internet (gateway endpoint, grátis).
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.principal.id
  service_name      = "com.amazonaws.${var.regiao}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.privada.id]

  tags = { Name = "${var.projeto}-vpce-s3" }
}
