# RDS do diagrama: PostgreSQL privado, acessível pela VPC, on-prem e Client VPN.
# A senha mestre é gerada e guardada pelo próprio RDS no Secrets Manager
# (manage_master_user_password) — não passa pelo terraform nem pelo state.

resource "aws_db_subnet_group" "principal" {
  name       = "${var.projeto}-rds"
  subnet_ids = aws_subnet.privada[*].id
  tags       = { Name = "${var.projeto}-rds" }
}

resource "aws_security_group" "rds" {
  name        = "${var.projeto}-rds"
  description = "PostgreSQL a partir da VPC, on-prem e Client VPN"
  vpc_id      = aws_vpc.principal.id

  ingress {
    description = "PostgreSQL"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = local.acesso_cidrs
  }

  tags = { Name = "${var.projeto}-sg-rds" }
}

resource "aws_db_instance" "principal" {
  identifier     = "${var.projeto}-rds"
  engine         = "postgres"
  engine_version = var.rds_engine_versao
  instance_class = var.rds_classe

  allocated_storage = var.rds_storage_gb
  storage_type      = "gp3"
  storage_encrypted = true

  db_name                     = "app"
  username                    = "dbadmin"
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.principal.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = var.rds_multi_az

  backup_retention_period   = 7
  skip_final_snapshot       = var.rds_pular_snapshot_final
  final_snapshot_identifier = var.rds_pular_snapshot_final ? null : "${var.projeto}-rds-final"
  deletion_protection       = !var.rds_pular_snapshot_final

  tags = { Name = "${var.projeto}-rds" }
}
