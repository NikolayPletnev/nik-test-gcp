output "load_balancer_ip" {
  description = "The external IP address of the load balancer"
  value       = google_compute_global_address.default.address
}

output "test_this" {
  description = "The HTTPS endpoint of the load balancer and the file"
  value       = "https://${google_compute_global_address.default.address}/${google_storage_bucket_object.test_image.name}"
}

output "test_with_domain" {
  description = "If you have registered DNS name, you can use this URL"
  value       = "https://${var.domain_name}/${google_storage_bucket_object.test_image.name}"
}