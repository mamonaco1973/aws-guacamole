# ================================================================================
# FILE: outputs.tf -- read by validate.sh
# ================================================================================

output "guacamole_url" {
  value = "https://${aws_lb.guacamole.dns_name}/"
}

output "guacamole_instance_id" { value = aws_instance.guacamole.id }
output "linux_private_ip" { value = aws_instance.linux.private_ip }
output "windows_private_ip" { value = aws_instance.windows_ad_instance.private_ip }
output "linux_instance_id" { value = aws_instance.linux.id }
output "windows_instance_id" { value = aws_instance.windows_ad_instance.id }
