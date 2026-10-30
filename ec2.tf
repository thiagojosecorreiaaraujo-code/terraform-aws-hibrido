# EC2 do diagrama: Amazon Linux 2023 em sub-rede privada, administrável a
# partir do on-prem e da Client VPN.

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_security_group" "ec2" {
  name        = "${var.projeto}-ec2"
  description = "SSH, HTTP e ICMP a partir da VPC, on-prem e Client VPN"
  vpc_id      = aws_vpc.principal.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = local.acesso_cidrs
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = local.acesso_cidrs
  }

  ingress {
    description = "Ping"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = local.acesso_cidrs
  }

  egress {
    description = "Saida"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.projeto}-sg-ec2" }
}

resource "aws_instance" "principal" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = var.ec2_tipo
  subnet_id              = aws_subnet.privada[0].id
  vpc_security_group_ids = [aws_security_group.ec2.id]

  metadata_options {
    http_tokens = "required" # IMDSv2
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
  }

  tags = { Name = "${var.projeto}-ec2" }
}
