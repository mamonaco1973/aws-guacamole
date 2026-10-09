# ================================================================================
# FILE: outputs.tf -- read by validate.sh
# ================================================================================

output "guacamole_url" {
  value = "https://${aws_lb.guacamole.dns_name}/"
}

output "guacamole_instance_id" { value = aws_instance.guacamole.id }
output "xubuntu_private_ip" { value = aws_instance.xubuntu.private_ip }
output "windows_private_ip" { value = aws_instance.windows_ad_instance.private_ip }
output "xubuntu_instance_id" { value = aws_instance.xubuntu.id }
output "windows_instance_id" { value = aws_instance.windows_ad_instance.id }
