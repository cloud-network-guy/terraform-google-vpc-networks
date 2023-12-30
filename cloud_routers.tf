locals {
  _cloud_routers = flatten([for vpc_network in local.vpc_networks :
    [for i, v in coalesce(vpc_network.cloud_routers, []) :
      {
        create                        = coalesce(v.create, true)
        project_id                    = coalesce(v.project_id, vpc_network.project_id, var.project_id)
        name                          = coalesce(v.name, "rtr-${i}")
        description                   = v.description
        region                        = coalesce(v.region, var.region)
        network                       = vpc_network.name
        enable_bgp                    = v.enable_bgp
        bgp_asn                       = v.bgp_asn
        bgp_keepalive_interval        = null
        advertise_mode                = length(coalesce(v.advertised_ip_ranges, [])) > 0 ? "CUSTOM" : "DEFAULT"
        advertised_groups             = coalesce(v.advertised_groups, [])
        advertised_ip_ranges          = coalesce(v.advertised_ip_ranges, [])
        encrypted_interconnect_router = coalesce(v.encrypted_interconnect_router, false)
      }
    ]
  ])
  __cloud_routers = [for i, v in local._cloud_routers :
    merge(v, {
      enable_bgp = coalesce(v.enable_bgp, v.bgp_asn != null || length(v.advertised_groups) > 0 || length(v.advertised_ip_ranges) > 0 ? true : false)
    })
  ]
  cloud_routers = [for i, v in local.__cloud_routers :
    merge(v, {
      bgp_asn                = v.enable_bgp ? coalesce(v.bgp_asn, 64512) : null
      bgp_keepalive_interval = v.enable_bgp ? coalesce(v.bgp_keepalive_interval, 20) : null
      index_key              = "${v.project_id}/${v.region}/${v.name}"
    }) if v.create == true
  ]
}

# Cloud Routers
resource "google_compute_router" "default" {
  for_each                      = { for k, v in local.cloud_routers : v.index_key => v }
  project                       = each.value.project_id
  name                          = each.value.name
  description                   = each.value.description
  network                       = each.value.network
  region                        = each.value.region
  encrypted_interconnect_router = each.value.encrypted_interconnect_router
  dynamic "bgp" {
    for_each = each.value.enable_bgp ? [true] : []
    content {
      asn                = each.value.bgp_asn
      keepalive_interval = each.value.bgp_keepalive_interval
      advertise_mode     = each.value.advertise_mode
      advertised_groups  = each.value.advertised_groups
      dynamic "advertised_ip_ranges" {
        for_each = each.value.advertised_ip_ranges
        content {
          range       = advertised_ip_ranges.value.range
          description = advertised_ip_ranges.value.description
        }
      }
    }
  }
  timeouts {
    create = null
    delete = null
    update = null
  }
  depends_on = [google_compute_network.default]
}
