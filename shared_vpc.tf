locals {
  # Create list of all service project IDs being shared to
  service_project_ids = flatten([for i, v in local.subnets : v.attached_projects])
}

# Retrieve project information for all service projects, given project ID
data "google_project" "service_projects" {
  for_each   = toset(local.service_project_ids)
  project_id = each.value
}

locals {
  # Form Map of keyed by Project ID with list of relevant compute service accounts
  compute_sa_accounts = { for project in data.google_project.service_projects :
    project.project_id => [
      "serviceAccount:${project.number}-compute@developer.gserviceaccount.com",
      "serviceAccount:${project.number}@cloudservices.gserviceaccount.com",
      # GKE = "serviceAccount:service-${project.number}@container-engine-robot.iam.gserviceaccount.com",
    ]
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
        for i, service_project_id in v.attached_projects : lookup(local.compute_sa_accounts, service_project_id, [])
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
