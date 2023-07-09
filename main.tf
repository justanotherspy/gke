terraform {
  required_version = ">= 1.0.0"
  backend "gcs" {
    bucket = "justanotherspy-terraform-state"
  }
}

provider "google" {
  project = "terraform-391612"
  region  = "europe-west1"
}

data "google_project" "project" {
  project_id = "terraform-391612"
}

resource "google_compute_subnetwork" "default" {
  name          = "gke-subnetwork"
  ip_cidr_range = "10.2.0.0/16"
  region        = "europe-west1"
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
  location                 = "europe-west1"
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.default.id
  subnetwork = google_compute_subnetwork.default.id

  workload_identity_config {
    workload_pool = "${data.google_project.project.project_id}.svc.id.goog"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "pod-ranges"
    services_secondary_range_name = google_compute_subnetwork.default.secondary_ip_range.0.range_name
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block = "209.203.45.252/32"
    }
  }

}


resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "gke-node-pool"
  location   = "europe-west1"
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_config {
    preemptible  = true
    machine_type = "e2-medium"
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    metadata = {
      "disable-legacy-endpoints" = "true"
    }

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.default.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}
