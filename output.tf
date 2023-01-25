output "instance_ip_addr" {
  value = aws_instance.instance.public_ip
}

output "s3_bucket_domain" {
  value = aws_s3_bucket.jekyll_bucket.website_domain
}

output "s3_bucket_endpoint" {
  value = aws_s3_bucket.jekyll_bucket.website_endpoint
}