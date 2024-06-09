output "ssh" {
  value       = aws_instance.minecraft.public_dns
  description = "URL to SSH into the server"
}

output "ip" {
  value       = var.static_ip ? aws_eip.minecraft[0].public_ip : aws_instance.minecraft.public_ip
  description = "The IPv4 address assigned to the server"
}
