################################################################################
# Sprint 1 & 2 — Secure Network Foundation + Managed Ansible Node
#
# This configuration implements the HealthConnect RFP security pillars:
# - Multi-tier network segmentation (Public / App / Data)
# - Zero-Trust Management: No Public IPs, all access via IAP Tunnel
# - Identity-Based Access: Centralized OS Login instead of manual SSH keys
# - Controlled Egress: Cloud NAT for private package updates
################################################################################

# 1) Custom VPC (no auto-generated subnets for maximum isolation)
resource "google_compute_network" "main_vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
}

# 2) Three-tier Subnet Architecture

# Tier 1: Public subnet (Reserved for Load Balancers/Bastions)
resource "google_compute_subnetwork" "public_subnet" {
  name          = "public-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.main_vpc.id
}

# Tier 2: Private application subnet (For Web/App Servers managed by Ansible)
resource "google_compute_subnetwork" "private_app_subnet" {
  name          = "private-app-subnet"
  ip_cidr_range = "10.0.2.0/24"
  region        = var.region
  network       = google_compute_network.main_vpc.id
}

# Tier 3: Isolated data subnet (For high-security Database workloads)
resource "google_compute_subnetwork" "data_isolated_subnet" {
  name          = "data-isolated-subnet"
  ip_cidr_range = "10.0.3.0/24"
  region        = var.region
  network       = google_compute_network.main_vpc.id
}

# 3) Cloud NAT for controlled egress
# Allows private instances to download updates (apt install) without public IPs
resource "google_compute_router" "router" {
  name    = "hc-router"
  region  = var.region
  network = google_compute_network.main_vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "hc-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# 4) Identity & Access Management (IAM) Configuration

# Enable OS Login at the project level
# MANDATORY: Replaces manual SSH keys with centralized IAM identity management
resource "google_compute_project_metadata_item" "enable_oslogin" {
  key   = "enable-oslogin"
  value = "TRUE"
}

# 5) Firewall Rules

# Allow SSH ONLY from Google's IAP TCP Forwarding range
# Forces all management traffic through the Identity-Aware Proxy
resource "google_compute_firewall" "allow_ssh_iap" {
  name    = "allow-ssh-iap"
  network = google_compute_network.main_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # Official Google IAP source range
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["hc-ansible-managed"]
}

# Allow Google Cloud Health Checks
resource "google_compute_firewall" "allow_health_checks" {
  name    = "allow-health-checks"
  network = google_compute_network.main_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080"]
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
}

# 6) Sprint 2 Managed VM (Consolidated hc-test-vm)
# Purpose: High-security Ansible node for automated portal deployment
resource "google_compute_instance" "test_vm" {
  name         = "hc-test-vm"
  machine_type = "e2-micro"
  zone         = "${var.region}-a"

  # Network tags for targeted firewall security
  tags = ["hc-ansible-managed"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  # ZERO-TRUST CONFIG: No 'access_config' block means NO External/Public IP
  network_interface {
    subnetwork = google_compute_subnetwork.private_app_subnet.id
  }

  # Essential for OS Login and API interaction
  service_account {
    scopes = ["cloud-platform"]
  }

  # Hard dependency to ensure security policies are active before VM creation
  depends_on = [google_compute_project_metadata_item.enable_oslogin]
}