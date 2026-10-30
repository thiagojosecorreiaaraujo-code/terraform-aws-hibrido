# Storage Gateway (VTL) do Data Center Corporativo.
#
# O appliance é uma VM instalada no hypervisor do data center (VMware/Hyper-V/
# KVM) — isso não é recurso AWS. O terraform faz a ATIVAÇÃO e a configuração
# do lado AWS quando var.storage_gateway_ip é informado. As fitas virtuais
# ficam em S3/Glacier gerenciados pelo serviço.

resource "aws_storagegateway_gateway" "vtl" {
  count = var.storage_gateway_ip == "" ? 0 : 1

  gateway_name        = "${var.projeto}-vtl"
  gateway_ip_address  = var.storage_gateway_ip
  gateway_type        = "VTL"
  gateway_timezone    = var.storage_gateway_fuso
  tape_drive_type     = "IBM-ULT3580-TD5"
  medium_changer_type = "AWS-Gateway-VTL"

  tags = { Name = "${var.projeto}-vtl" }
}

# Pool de fitas com retenção em Glacier Deep Archive (arquivamento barato).
resource "aws_storagegateway_tape_pool" "arquivo" {
  count               = var.storage_gateway_ip == "" ? 0 : 1
  pool_name           = "${var.projeto}-deep-archive"
  storage_class       = "DEEP_ARCHIVE"
  retention_lock_type = "NONE"
}
