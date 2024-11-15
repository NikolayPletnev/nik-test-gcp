terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "6.8.0"
    }
  }
}

data "google_project" "current" {
  project_id = var.project_id
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = "${var.region}-b"
}

resource "google_compute_project_default_network_tier" "default" {
  network_tier = "PREMIUM"
}

resource "google_compute_network" "vpc_network" {
  name = "gcp-test-network"
}

# Cloud Storage bucket
resource "random_id" "bucket_prefix" {
  byte_length = 8
}

resource "google_storage_bucket" "private_bucket" {
  name                        = "${random_id.bucket_prefix.hex}-nik-test-bucket"
  location                    = var.region
  uniform_bucket_level_access = true
  storage_class               = "STANDARD"
  // delete bucket and contents on destroy.
  force_destroy = true
  // Assign specialty files
  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }
}

# image object for testing, try to access https://<lb_ip_address>/test.jpg
resource "google_storage_bucket_object" "test_image" {
  name = "test.jpg"
   source       = "test/1.jpg"
   content_type = "image/jpeg"

  bucket = google_storage_bucket.private_bucket.name
}

resource "google_storage_bucket_iam_member" "default" {
  bucket = google_storage_bucket.private_bucket.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

resource "google_compute_global_address" "default" {
  name = "nik-test-ip"
}

# Backend bucket with CDN policy with default ttl settings
resource "google_compute_backend_bucket" "backend_bucket" {
  name        = "nik-backend-bucket"
  description = "Contains static data"
  bucket_name = google_storage_bucket.private_bucket.name
  enable_cdn  = true
  cdn_policy {
    cache_mode        = "CACHE_ALL_STATIC"
    client_ttl        = 3600
    default_ttl       = 3600
    max_ttl           = 86400
    negative_caching  = true
    serve_while_stale = 86400
  }
}

resource "google_compute_url_map" "default" {
  name            = "https-lb"
  default_service = google_compute_backend_bucket.backend_bucket.id

}

# It's not secure to store certs in GitHub, but this one is self-signed
resource "google_compute_ssl_certificate" "default" {
  name        = "nikdevops-certificate"
  private_key = file("ssl_certs/key.pem")
  certificate = file("ssl_certs/cert.pem")
}

# Https proxy
resource "google_compute_target_https_proxy" "default" {
  name    = "https-lb-proxy"
  url_map = google_compute_url_map.default.id
  ssl_certificates = [google_compute_ssl_certificate.default.id]
}

# Forwarding rules
resource "google_compute_global_forwarding_rule" "default" {
  name                  = "https-lb-forwarding-rule"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "443"
  target                = google_compute_target_https_proxy.default.id
  ip_address            = google_compute_global_address.default.address
}

# Http proxy
resource "google_compute_target_http_proxy" "http-redirect" {
  name    = "http-redirect"
  url_map = google_compute_url_map.default.id
}

resource "google_compute_global_forwarding_rule" "http-redirect" {
  name       = "http-redirect"
  target     = google_compute_target_http_proxy.http-redirect.id
  ip_address = google_compute_global_address.default.address
  port_range = "80"
}

resource "google_dns_managed_zone" "dns_zone" {
  name        = "cdn-dns-zone"
  dns_name    = "${var.domain_name}."
  description = "DNS zone for the custom domain."
}

resource "google_dns_record_set" "cdn_dns_record" {
  name         = "${var.domain_name}."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.dns_zone.name

  rrdatas = [google_compute_global_forwarding_rule.default.ip_address]
}