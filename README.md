# Management of GCP VPC Networks and their components:

- Subnets & IP Ranges
- Cloud Routers
- Cloud NATs
- Peering Connections
- Static Routes
- Firewall Rules
- IP Ranges
- Private Service Connects
- Shared VPC Permissions
- Serverless VPC Access Connectors

## Resources 

- [google_compute_address]
- [google_compute_firewall]
- [google_compute_global_address]
- [google_compute_network](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network)
- [google_compute_network_peering]
- [google_compute_network_peering_routes_config]
- [google_compute_route]
- [google_compute_router]
- [google_compute_router_nat]
- [google_compute_subnetwork]
- [google_compute_subnetwork_iam_binding]
- [google_service_networking_connection]
- [google_vpc_access_connector]

## Inputs 

### Global Inputs

| Name                   | Description                      | Type           | Default |
|------------------------|----------------------------------|----------------|---------|
| project_id             | Default GCP Project ID           | `string`       | n/a     |
| region                 | Default GCP Region               | `string`       | n/a     |
| vpc_networks           | List of VPC Networks (see below) | `list(object)` | n/a     |

### vpc_networks

`var.vpc_networks` is a list of objects.  Attributes are described below

| Name                    | Description                                   | Type           | Default |
|-------------------------|-----------------------------------------------|----------------|---------|
| mtu                     | IP MTU Value                                  | `number`       | 0       |
| enable_global_routing   | Use Global Routing rather than Regional       | `bool`         | false   |
| auto_create_subnetworks | Automatically create subnets for each region  | `bool`         | false   |
| service_project_ids     | Shared VPC Service Projects list              | `list(string)` | []      |
| shared_accounts         | Specific accounts to share all subnets to     | `list(string)` | []      |
| subnets                 | List of Subnetworks (see below)               | `list(object)` | []      |
| routes                  | List of Routes (see below)                    | `list(object)` | []      |
| peerings                | List of VPC Peering Connections (see below)   | `list(object)` | []      |
| ip_ranges               | List of Private Service IP Ranges (see below) | `list(object)` | []      |
| cloud_routers           | List of Cloud Routers (see below)             | `list(object)` | []      |
| cloud_nats              | List of Cloud NATs (see below)                | `list(object)` | []      |

Example:

```terraform
vpc_networks = [
  {
    name                  = "my-vpc-1"
    enable_global_routing = true
  },
  {
    name                    = "my-vpc-2"
    auto_create_subnetworks = true
  },
]

```


#### subnets

`var.vpc_networks.subnets` is a list of objects.  Attributes are described below

| Name                | Description                                 | Type      | Default  |
|---------------------|---------------------------------------------|-----------|----------|
| name                | Subnetwork Name                             | `string`  | n/a      |
| description         | Subnetwork Description                      | `string`  | null     |
| region              | GCP Region                                  | `string`  | n/a      |
| ip_range            | Main IP Range CIDR                          | `string`  | n/a      |
| purpose             | Subnet Purpose                              | `string`  | PRIVATE  |
| role                | For Proxy-Only Subnets, the role            | `string`  | ACTIVE   |
| private_access      | Enable Private Google Access                | `bool`    | false    | 
| flow_logs           | Enable Flow Logs on this subnet             | `bool`    | false    |
| service_project_ids | Shared VPC Service Projects list            | `list(string)` | []      |
| shared_accounts     | Specific accounts to share this subnets to  | `list(string)` | []      |

Examples

```terraform
    subnets = [
      {
        name     = "subnet1"
        region   = "us-east1"
        ip_range = "172.29.1.0/24"
      }
    ]
```


#### peerings

`var.vpc_networks.peerings` is a list of objects.  Attributes are described below

| Name                                | Description                               | Type     | Default   |
|-------------------------------------|-------------------------------------------|----------|-----------|
| name                                | Peering Connection Name                   | `string` | n/a       |
| peer_project_id                     | Project ID of Peer                        | `string` | null      |
| peer_network_name                   | VPC Network Name in that project          | `string` | n/a       | 
| peer_network_link                   | Peer Self Link (projects/peer-project...) | `string` | n/a       | 
| import_custom_routes                |                                           | bool     | false     |
| export_custom_routes                |                                           | bool     | false     |
| import_subnet_routes_with_public_ip |                                           | bool     | false     | 
| export_subnet_routes_with_public_ip |                                           | bool     | false     | 

Examples

```terraform
  peerings = [
      {
        name              = "peering1"
        peer_project_id   = "other-project"
        peer_network_name = "other-network"
      }
    ]
```
## IMPORT examples


```
```


