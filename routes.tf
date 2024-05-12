locals {
  _routes = flatten([for vpc_network in local.vpc_networks :
    [for i, v in coalesce(vpc_network.routes, []) :
      merge(v, {
        create      = coalesce(v.create, true)
        project_id  = coalesce(v.project_id, vpc_network.project_id, var.project_id)
        name        = lower(trimspace(replace(replace(coalesce(v.name, replace(v.dest_range, ".", "-")), "/", "-"), "_", "-")))
        next_hop    = coalesce(v.next_hop, "default-internet-gateway")
        network     = vpc_network.name
        dest_range  = v.dest_range
        dest_ranges = coalesce(v.dest_ranges, [])
        tags        = coalesce(v.tags, [])
      })
    ]
  ])
  __routes = flatten(concat(
    [for route in local._routes :
      # Routes that have more than one destination range
      [for i, dest_range in route.dest_ranges :
        merge(route, {
          name       = "${route.name}-${replace(replace(dest_range, ".", "-"), "/", "-")}-${route.priority}"
          dest_range = dest_range
        })
      ]
    ],
    # Routes with a single destination range
    [for i, v in local._routes :
      merge(v, {
      }) if v.dest_range != null
    ]
  ))
  ___routes = [for i, v in local.__routes :
    merge(v, {
      network       = "${local.url_prefix}/${v.project_id}/global/networks/${v.network}"
      next_hop_type = can(regex("^[1-2]", v.next_hop)) ? "ip" : (endswith(v.next_hop, "gateway") ? "gateway" : "instance")
      index_key     = "${v.project_id}/${v.name}"
    }) if v.create == true
  ]
  routes = [for i, v in local.___routes :
    merge(v, {
      next_hop_gateway       = v.next_hop_type == "gateway" ? "${local.url_prefix}/${v.project_id}/global/gateways/${v.next_hop}" : null
      next_hop_ip            = v.next_hop_type == "ip" ? v.next_hop : null
      next_hop_instance      = v.next_hop_type == "instance" ? v.next_hop : null
      next_hop_instance_zone = v.next_hop_type == "instance" ? v.next_hop_zone : null
      index_key              = "${v.project_id}/${v.name}"
    }) if v.create == true
  ]
}

# Static Routes
resource "google_compute_route" "default" {
  for_each               = { for i, v in local.routes : v.index_key => v }
  project                = var.project_id
  name                   = each.value.name
  description            = each.value.description
  network                = each.value.network
  dest_range             = each.value.dest_range
  priority               = each.value.priority
  tags                   = each.value.tags
  next_hop_gateway       = each.value.next_hop_gateway
  next_hop_ip            = each.value.next_hop_ip
  next_hop_instance      = each.value.next_hop_instance
  next_hop_instance_zone = each.value.next_hop_instance_zone
  depends_on             = [google_compute_network.default]
}
