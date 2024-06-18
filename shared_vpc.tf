locals {
  # Create list of all service project IDs being shared to
  service_project_ids = toset(flatten([for i, v in local.subnets : v.attached_projects]))
}

# Retrieve project information for all service projects, given project ID
data "google_project" "service_projects" {
  for_each   = local.service_project_ids
  project_id = each.value
}

# Configure Asset Resource Manage to use Host VPC as quota/billing project
provider "google-beta" {
  user_project_override = true
  billing_project       = coalesce(var.vpc_networks[0].project_id, var.project_id)
}

# Retrieve enabled services (APIs) for all service projects, given project ID
data "google_cloud_asset_resources_search_all" "services" {
  for_each    = local.service_project_ids
  scope       = "projects/${each.value}"
  asset_types = ["serviceusage.googleapis.com/Service"]
  provider    = google-beta
}

locals {
  # Form Map of keyed by Project ID with Project Number & list of enabled services (APIs)
  projects = { for project_id in local.service_project_ids :
    project_id => {
      number = data.google_project.service_projects[project_id].number
      apis   = toset(compact([for _ in data.google_cloud_asset_resources_search_all.services[project_id].results : lookup(_, "display_name", null)]))
    }
  }
  # For each Project ID, create a list of service accounts needing compute.networkUser permissions
  service_accounts = { for k, v in local.projects :
    k => compact([
      contains(v.apis, "compute.googleapis.com") ? "serviceAccount:${v.number}@cloudservices.gserviceaccount.com" : null,
      contains(v.apis, "compute.googleapis.com") ? "serviceAccount:${v.number}-compute@developer.gserviceaccount.com" : null,
      contains(v.apis, "container.googleapis.com") ? "serviceAccount:service-${v.number}@container-engine-robot.iam.gserviceaccount.com" : null,
    ])
  }
  # Create a list of objects for all subnets that are shared
  shared_subnets = flatten([for k, v in local.subnets :
    {
      subnet_key = v.index_key
      project_id = v.project_id
      region     = v.region
      subnetwork = "projects/${v.project_id}/regions/${v.region}/subnetworks/${v.name}"
      role       = "roles/compute.networkUser"
      members = toset(flatten(concat([
        for i, service_project_id in v.attached_projects : lookup(local.service_accounts, service_project_id, [])
      ], v.shared_accounts)))
    } if length(v.attached_projects) > 0 || length(v.shared_accounts) > 0 && v.is_private
  ])
  # Same for viewer
  viewable_subnets = flatten([for k, v in local.subnets :
    {
      subnet_key = v.index_key
      project_id = v.project_id
      region     = v.region
      subnetwork = "projects/${v.project_id}/regions/${v.region}/subnetworks/${v.name}"
      role       = "roles/compute.networkViewer"
      members    = toset(v.viewer_accounts)
    } if length(v.viewer_accounts) > 0 && v.is_private
  ])
}

# Give Compute Network User permissions on the subnet to the applicable accounts
resource "google_compute_subnetwork_iam_binding" "default" {
  for_each   = { for i, v in local.shared_subnets : v.subnet_key => v }
  project    = each.value.project_id
  region     = each.value.region
  subnetwork = each.value.subnetwork
  role       = each.value.role
  members    = each.value.members
  depends_on = [google_compute_subnetwork.default]
}

# Give Compute Network Viewer permissions on the subnet to the applicable accounts
resource "google_compute_subnetwork_iam_binding" "viewer" {
  for_each   = { for i, v in local.viewable_subnets : v.subnet_key => v }
  project    = each.value.project_id
  region     = each.value.region
  subnetwork = each.value.subnetwork
  role       = each.value.role
  members    = each.value.members
  depends_on = [google_compute_subnetwork.default]
}
