locals {
  _psc_endpoints = flatten([for subnet in local.subnets :
    [for i, v in subnet.psc_endpoints :
      {
        project_id  = coalesce(lookup(v, "project_id", null), subnet.project_id)
        network     = subnet.network
        region      = subnet.region
        subnetwork  = google_compute_subnetwork.default[subnet.index_key].id
        name        = coalesce(lookup(v, "name", null), "psc-endpoint-${i + 1}")
        description = lookup(v, "description", null)
        address     = lookup(v, "address", null)
        target      = startswith(local.url_prefix, v.target) ? v.target : "${local.url_prefix}/${v.target}"
      }
    ]
  ])
  psc_endpoints = [for i, v in local._psc_endpoints :
    merge(v, {
      index_key = "${v.project_id}/${v.region}/${v.name}"
    })
  ]
}

# Regional Internal Static IP address for PSC Consumer Endpoint
resource "google_compute_address" "default" {
  for_each      = { for i, v in local.psc_endpoints : v.index_key => v }
  project       = each.value.project_id
  name          = each.value.name
  description   = each.value.description
  region        = each.value.region
  subnetwork    = each.value.subnetwork
  address_type  = "INTERNAL"
  purpose       = "GCE_ENDPOINT"
  network_tier  = "PREMIUM"
  address       = each.value.address
  ip_version    = ""
  prefix_length = 0
  depends_on    = [null_resource.subnets]
}

# Regional Internal Forwarding Rule for PSC Consumer Endpoint
resource "google_compute_forwarding_rule" "default" {
  for_each              = { for i, v in local.psc_endpoints : v.index_key => v }
  project               = each.value.project_id
  name                  = each.value.name
  description           = each.value.description
  network               = each.value.network
  region                = each.value.region
  ip_address            = google_compute_address.default[each.value.index_key].self_link
  target                = each.value.target
  subnetwork            = null
  load_balancing_scheme = ""
  all_ports             = false
  allow_global_access   = false
  depends_on            = [google_compute_network.default]
}