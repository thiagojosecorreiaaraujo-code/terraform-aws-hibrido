# terraform-aws-hibrido

Topologia híbrida: Nuvem AWS (S3, RDS, Lambda, EC2) ligada por **Transit Gateway**
a dois sites on-prem via **VPN IPSec pela internet**, mais **usuários remotos por
VPN SSL (Client VPN)**.

## Diagrama → arquivo

| Bloco do diagrama | Arquivo | Recursos |
|---|---|---|
| Nuvem AWS (rede) | `vpc.tf` | VPC, 2 sub-redes privadas, rotas on-prem → TGW, endpoint S3 |
| S3 | `s3.tf` | bucket privado, versionado, criptografado |
| RDS | `rds.tf` | PostgreSQL privado; senha no Secrets Manager (gerada pelo RDS) |
| Lambda | `lambda.tf` + `lambda/handler.py` | função Python na VPC, acesso ao S3 e RDS |
| EC2 | `ec2.tf` | Amazon Linux 2023 em sub-rede privada, IMDSv2 |
| Transit Gateway | `transit_gateway.tf` | TGW + anexo da VPC |
| IPSec VPN (Escritórios e Filiais) | `vpn_site_to_site.tf` | Customer Gateway + VPN (2 túneis) no TGW |
| IPSec VPN (Data Center Corporativo) | `vpn_site_to_site.tf` | Customer Gateway + VPN (2 túneis) no TGW |
| Client VPN / Usuários remotos VPN SSL | `client_vpn.tf` | endpoint OpenVPN 443/UDP, certificados, logs, `.ovpn` |
| Storage Gateway (VTL) | `storage_gateway.tf` | ativação do gateway de fitas + pool Deep Archive |

**Fora do Terraform AWS** (existem fisicamente no diagrama):

- **MPLS** entre Escritórios e Data Center: link do provedor de telecom. Como as
  duas VPNs caem no mesmo Transit Gateway, a AWS também vira **rota de
  contingência** entre os sites se o MPLS cair.
- **Servidores** do data center.
- **VM do Storage Gateway**: baixe a imagem no console (Storage Gateway → Create
  gateway → Tape gateway) e instale no hypervisor. O Terraform só **ativa** o
  gateway quando você informa o IP dela em `storage_gateway_ip`.

## Uso

```bash
cp terraform.tfvars.example terraform.tfvars   # preencha IPs públicos e CIDRs
terraform init
terraform test        # plan com AWS simulado: prova a topologia sem credenciais
terraform plan
terraform apply
```

Depois do `apply`:

1. **Firewalls dos sites:** `terraform output vpn_tuneis` dá os IPs dos túneis, e
   `terraform output -json vpn_chaves_psk` dá as chaves. O arquivo de
   configuração por fabricante (Cisco, Fortinet, pfSense…) sai no console:
   VPC → Site-to-Site VPN → *Download configuration*. Parâmetros: IKEv2,
   AES-256, SHA2-256, DH 14.
2. **Usuários remotos:** distribua `saida/cliente-<projeto>.ovpn` e importe no
   AWS VPN Client ou OpenVPN.
3. **Storage Gateway:** com a VM no ar, ajuste `storage_gateway_ip` e rode
   `apply` de novo. A máquina que roda o Terraform precisa alcançar esse IP na
   porta 80, por exemplo pela própria VPN.

## Atenção

- O **state** contém as chaves privadas da Client VPN e as PSKs dos túneis.
  Use o backend S3 criptografado (bloco comentado em `versions.tf`). Nunca
  versione `*.tfstate`, `terraform.tfvars` ou `saida/` (já estão no `.gitignore`).
- O certificado de cliente é **um só, compartilhado**. Para revogar por pessoa,
  gere um por usuário repetindo o bloco `cliente` em `client_vpn.tf`.
- **Custo por hora** mesmo sem tráfego: anexos do Transit Gateway (VPC + 2 VPNs),
  2 conexões VPN, associações da Client VPN (uma por AZ) e RDS. Para laboratório,
  rode `terraform destroy` ao terminar.
- Com `vpn_rota_estatica = false` as VPNs usam BGP. Configure os ASNs dos
  roteadores em `escritorios_bgp_asn` / `datacenter_bgp_asn`.
