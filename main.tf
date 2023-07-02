terraform {
  required_version = ">= 1.0.0"
  backend "gcs" {
    bucket = "justanotherspy-terraform-state"
  }
}

provider "google" {
  project = "terraform-391612"
  region  = "eu-west1"
}

resource "google_compute_subnetwork" "default" {
  name          = "gke-subnetwork"
  ip_cidr_range = "10.2.0.0/16"
  region        = "eu-west1"
  network       = google_compute_network.default.id
  secondary_ip_range {
    range_name    = "services-range"
    ip_cidr_range = "192.168.1.0/24"
  }

  secondary_ip_range {
    range_name    = "pod-ranges"
    ip_cidr_range = "192.168.64.0/22"
  }
}

resource "google_compute_network" "default" {
  name                    = "gke-network"
  auto_create_subnetworks = false
}

resource "google_service_account" "default" {
  account_id   = "gke-node-service-account"
  display_name = "Service Account for GKE Nodes"
}

resource "google_container_cluster" "primary" {
  name                     = "gke-cluster"
  location                 = "eu-west1"
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.default.id
  subnetwork = google_compute_subnetwork.default.id

  ip_allocation_policy {
    cluster_secondary_range_name  = "pod-ranges"
    services_secondary_range_name = google_compute_subnetwork.default.secondary_ip_range.0.range_name
  }

}


resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "gke-node-pool"
  location   = "eu-west1"
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_config {
    preemptible  = true
    machine_type = "e2-medium"

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.default.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}
