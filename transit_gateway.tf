# Transit Gateway: o hub do diagrama. Liga a VPC aos dois túneis IPSec
# (Escritórios e Filiais + Data Center Corporativo).

resource "aws_ec2_transit_gateway" "principal" {
  description                     = "${var.projeto} - hub VPC + VPNs on-prem"
  amazon_side_asn                 = 64512
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"

  tags = { Name = "${var.projeto}-tgw" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "vpc" {
  transit_gateway_id = aws_ec2_transit_gateway.principal.id
  vpc_id             = aws_vpc.principal.id
  subnet_ids         = aws_subnet.privada[*].id
  dns_support        = "enable"

  tags = { Name = "${var.projeto}-tgw-anexo-vpc" }
}
