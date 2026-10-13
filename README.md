# Azure Hub-Spoke Network

Terraform for a hub-and-spoke network on Azure. One hub VNet holds a firewall and shared services. Spoke VNets hold workloads. All spoke traffic goes through the firewall, and PaaS services are reached over private endpoints instead of the public internet.

## Architecture

```
                    +---------------------------+
                    |  Internet                 |
                    +-------------+-------------+
                                  |
                    +-------------v-------------+
                    |  Hub VNet  10.0.0.0/16    |
                    |  - AzureFirewallSubnet    |
                    |  - snet-management       |
                    |  - Azure Firewall         |
                    |  - Private DNS zone      |
                    +------+------+-------------+
                           |      |
              peering      |      |      peering
                           |      |
        +------------------v--+  +--v------------------+
        | Spoke App          |  | Spoke Data           |
        | 10.1.0.0/16        |  | 10.2.0.0/16         |
        | - snet-workload    |  | - snet-workload      |
        | - NSG, route table |  | - NSG, route table   |
        | - Storage private  |  |                      |
        |   endpoint         |  |                      |
        +---------------------+  +----------------------+
```

## Design decisions

- **One hub, many spokes.** The hub owns shared services (firewall, DNS). Spokes own workloads. A new team gets a new spoke, not a new network design.
- **Default route through the firewall.** Each spoke route table sends `0.0.0.0/0` to the firewall as a virtual appliance. Spokes have no direct internet path, so egress policy lives in one place.
- **Firewall policy, not ad-hoc rules.** Egress rules (DNS, HTTPS) live in a firewall policy rule collection group. Adding a spoke means adding its range to the rule, not rebuilding the firewall.
- **Private endpoints for PaaS.** The storage account has public access disabled. Spoke workloads resolve `privatelink.blob.core.windows.net` to the private endpoint IP through the private DNS zone. The same pattern works for Key Vault, SQL, ACR, and other privatelink services.
- **NSGs as a second layer.** Spoke NSGs allow HTTPS from the hub range. They are not the main control; the firewall and route tables are. NSGs exist so a misconfigured route does not silently open a spoke.

## Files

| File | What it holds |
| --- | --- |
| `main.tf` | Resource group, hub and spoke VNets, firewall, NSGs, peering |
| `routes.tf` | Spoke route tables and subnet associations |
| `dns.tf` | Private DNS zone, links, storage account, private endpoint |
| `variables.tf` | Inputs (region, prefixes, address spaces) |
| `outputs.tf` | IDs and IPs you need after apply |

## Deploy

```bash
az login
terraform init
terraform plan
terraform apply
```

## Destroy

```bash
terraform destroy
```

The firewall bills hourly, so destroy the deployment when you are done testing. It is the main cost in this setup.

## Notes

- The firewall subnet name `AzureFirewallSubnet` is reserved by Azure and must match exactly.
- Peering is created in both directions. The hub side allows forwarded traffic so spoke-to-spoke traffic can pass through the firewall.
- This is a reference layout. For production, add a VPN or ExpressRoute gateway in the hub, Azure Bastion for admin access, and firewall logging to Log Analytics.
