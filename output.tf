output "instance_ip_addr" {
  value = aws_instance.instance.public_ip
}

output "s3_bucket_domain" {
  value = aws_s3_bucket_website_configuration.jekyll_bucket_website.website_domain
}

output "s3_bucket_name" {
  value = aws_s3_bucket.jekyll_bucket.id
}

output "s3_bucket_endpoint" {
  value = aws_s3_bucket_website_configuration.jekyll_bucket_website.website_endpoint
}

# output "tls" {
#   value = tls_private_key.instancessh.private_key_openssh
#   sensitive = true
# }