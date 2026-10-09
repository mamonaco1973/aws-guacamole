# ================================================================================
# Active Directory Naming Inputs
# ================================================================================
# Purpose:
#   - Defines AD domain identity inputs used by Samba and Kerberos.
#
# Notes:
#   - dns_zone is the AD DNS domain (FQDN).
#   - realm is typically dns_zone in uppercase for Kerberos.
#   - netbios is the short legacy domain name (<= 15 chars recommended).
# ================================================================================

# ------------------------------------------------------------------------------
# VARIABLE: dns_zone
# ------------------------------------------------------------------------------
# Purpose:
#   - Fully qualified DNS name for the AD domain.
# ------------------------------------------------------------------------------
variable "dns_zone" {
  description = "AD DNS zone / domain (e.g., mcloud.mikecloud.com)"
  type        = string
  default     = "mcloud.mikecloud.com"
}

# ------------------------------------------------------------------------------
# VARIABLE: realm
# ------------------------------------------------------------------------------
# Purpose:
#   - Kerberos realm for the AD domain.
#
# Notes:
#   - Convention is to match dns_zone in uppercase.
# ------------------------------------------------------------------------------
variable "realm" {
  description = "Kerberos realm (uppercase DNS domain)"
  type        = string
  default     = "MCLOUD.MIKECLOUD.COM"
}

# ------------------------------------------------------------------------------
# VARIABLE: netbios
# ------------------------------------------------------------------------------
# Purpose:
#   - Short NetBIOS domain name for legacy and SMB clients.
#
# Notes:
#   - Recommended length is 15 characters or fewer.
# ------------------------------------------------------------------------------
variable "netbios" {
  description = "NetBIOS short domain name (e.g., MCLOUD)"
  type        = string
  default     = "MCLOUD"
}

# ================================================================================
# Networking Inputs
# ================================================================================

# ------------------------------------------------------------------------------
# VARIABLE: vpc_name
# ------------------------------------------------------------------------------
# Purpose:
#   - Name tag used to locate or label the target VPC.
# ------------------------------------------------------------------------------
variable "vpc_name" {
  description = "Name for the VPC"
  type        = string
  default     = "efs-vpc"
}

# ------------------------------------------------------------------------------
# VARIABLE: dc_hostname
# ------------------------------------------------------------------------------
# Purpose:
#   - Short hostname of the mini-AD domain controller (HOSTNAME_DC in the
#     module, "ad1"). Combined with dns_zone to form the DC FQDN used by the
#     sssd-ldap client for ldaps:// and the /ca.pem fetch.
# ------------------------------------------------------------------------------
variable "dc_hostname" {
  description = "Short hostname of the mini-AD domain controller"
  type        = string
  default     = "ad1"
}

# ================================================================================
# Guacamole Inputs
# ================================================================================

# ------------------------------------------------------------------------------
# VARIABLE: allowed_cidrs
# ------------------------------------------------------------------------------
# Purpose:
#   - Who may reach the Guacamole ALB. Open by default; every login still
#     needs an AD account in mcloud-users. Narrow it to your own address
#     with, e.g., TF_VAR_allowed_cidrs='["203.0.113.7/32"]'.
# ------------------------------------------------------------------------------
variable "allowed_cidrs" {
  description = "CIDR blocks allowed to reach the Guacamole ALB"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
