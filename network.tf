################################################################################
# Sprint 1, 2 & 3 — Secure Network Foundation + Multi-tier Application Stack
# 
# Pillars:
# - Multi-tier isolation (Public / App / Data)
# - Zero-Trust Management (No Public IPs, IAP & OS Login enforced)
# - Secure Database Integration (Restricted internal communication)
################################################################################

# 1) Custom VPC
resource "google_compute_network" "main_vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
}

# 2) Three-tier Subnet Architecture
resource "google_compute_subnetwork" "public_subnet" {
  name          = "public-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.main_vpc.id
}

resource "google_compute_subnetwork" "private_app_subnet" {
  name          = "private-app-subnet"
  ip_cidr_range = "10.0.2.0/24"
  region        = var.region
  network       = google_compute_network.main_vpc.id
}

resource "google_compute_subnetwork" "data_isolated_subnet" {
  name          = "data-isolated-subnet"
  ip_cidr_range = "10.0.3.0/24"
  region        = var.region
  network       = google_compute_network.main_vpc.id
}

# 3) Cloud NAT for controlled egress (Internal instances can run 'apt update')
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

# 4) Identity-Based Security (OS Login)
resource "google_compute_project_metadata_item" "enable_oslogin" {
  key   = "enable-oslogin"
  value = "TRUE"
}

# 5) Firewall Rules

# Allow SSH only via IAP Tunnel
resource "google_compute_firewall" "allow_ssh_iap" {
  name    = "allow-ssh-iap"
  network = google_compute_network.main_vpc.name
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["35.235.240.0/20"]
  # Targets both App and DB VMs for secure management
  target_tags = ["hc-ansible-managed", "hc-db-managed"]
}

# SPRINT 3 ADDITION: Internal firewall rule for App-to-DB connectivity
resource "google_compute_firewall" "allow_db_from_app" {
  name    = "allow-db-from-app"
  network = google_compute_network.main_vpc.name
  allow {
    protocol = "tcp"
    ports    = ["5432"] # Default PostgreSQL port
  }
  # Restrict access only from the App Tier to the Data Tier
  source_tags = ["hc-ansible-managed"]
  target_tags = ["hc-db-managed"]
}

# 6) Managed VM Instances (Zero-Trust)

# App Server (hc-test-vm)
resource "google_compute_instance" "test_vm" {
  name         = "hc-test-vm"
  machine_type = "e2-micro"
  zone         = "${var.region}-c"
  tags         = ["hc-ansible-managed"]

  boot_disk {
    initialize_params { image = "debian-cloud/debian-12" }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private_app_subnet.id
    # No access_config = No Public IP
  }

  service_account { scopes = ["cloud-platform"] }
  depends_on = [google_compute_project_metadata_item.enable_oslogin]
}

# SPRINT 3 ADDITION: Database Server (hc-db-vm)
resource "google_compute_instance" "db_vm" {
  name         = "hc-db-vm"
  machine_type = "e2-micro"
  zone         = "${var.region}-c"
  tags         = ["hc-db-managed"]

  boot_disk {
    initialize_params { image = "debian-cloud/debian-12" }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.data_isolated_subnet.id
    # No access_config = No Public IP (Isolated Data Tier)
  }

  service_account { scopes = ["cloud-platform"] }
  depends_on = [google_compute_project_metadata_item.enable_oslogin]
}

# 7) Sprint 4 Addition: High Availability & Scaling
# Purpose: Eliminate single points of failure by adding a secondary Web Node

# Secondary App Server (hc-web-2)
resource "google_compute_instance" "web_2" {
  name         = "hc-web-2"
  machine_type = "e2-micro"
  zone         = "${var.region}-c"

  # Must share the same tag as test_vm for consistent Firewall & Ansible application
  tags = ["hc-ansible-managed"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private_app_subnet.id
    # No access_config = Enforces RFP 4.1 (Logical Isolation)
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  # Ensures OS Login is ready before instance creation
  depends_on = [google_compute_project_metadata_item.enable_oslogin]
}

# 8) Backend Service Foundation: Unmanaged Instance Group
# Purpose: Grouping Web Nodes to act as a single backend for the Load Balancer
resource "google_compute_instance_group" "web_group" {
  name        = "hc-web-group"
  description = "High-availability web cluster for HealthConnect Portal"
  zone        = "${var.region}-c"

  # Register both Web Nodes into the group
  instances = [
    google_compute_instance.test_vm.id,
    google_compute_instance.web_2.id,
  ]

  named_port {
    name = "http"
    port = 80
  }
}

# 9) Load Balancer Firewall Requirement
# Purpose: Allow Google Cloud Health Check ranges to reach the instances
resource "google_compute_firewall" "allow_lb_health_check" {
  name    = "allow-lb-health-check"
  network = google_compute_network.main_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  # Official Google Cloud Health Check IP ranges
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["hc-ansible-managed"]
}