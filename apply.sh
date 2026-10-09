#!/bin/bash
# ================================================================================
# Active Directory + Dependent Server Deployment Orchestration Script
# ================================================================================
# Description:
#   Automates a three-phase AWS infrastructure build:
#     1. Network + Active Directory (AD) Domain Controller.
#     2. The Xubuntu + XRDP desktop AMI (Packer).
#     3. The ALB, Guacamole, and the Windows and Xubuntu servers.
#
# Notes:
#   - Fail-fast enabled: any error terminates execution immediately.
# ================================================================================
 
set -euo pipefail
 
# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------
export AWS_DEFAULT_REGION="us-east-1"
DNS_ZONE="mcloud.mikecloud.com"
 
# ------------------------------------------------------------------------------
# Environment Pre-Check
# ------------------------------------------------------------------------------
echo "NOTE: Running environment validation..."
./check_env.sh
 
# ------------------------------------------------------------------------------
# Phase 1: Build AD Instance
# ------------------------------------------------------------------------------
echo "NOTE: Building Active Directory instance..."
 
cd 01-directory || { echo "ERROR: Directory 01-directory not found"; exit 1; }
 
terraform init
terraform apply -auto-approve
 
cd ..
 
# ------------------------------------------------------------------------------
# Phase 2: Build the Xubuntu + XRDP AMI (Packer)
# ------------------------------------------------------------------------------
# The build instance needs a public IP for Packer's SSH, so it runs in the
# public subnet of the phase-1 VPC. Each run builds a new AMI; phase 3 takes
# the newest, and destroy.sh deregisters them all.
# ------------------------------------------------------------------------------
echo "NOTE: Building the Xubuntu + XRDP AMI with Packer..."

vpc_id=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=efs-vpc" \
  --query "Vpcs[0].VpcId" --output text)
subnet_id=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=${vpc_id}" "Name=tag:Name,Values=vm-subnet-1" \
  --query "Subnets[0].SubnetId" --output text)

cd 02-packer || { echo "ERROR: Directory 02-packer not found"; exit 1; }

packer init ./xubuntu.pkr.hcl
packer build \
  -var "vpc_id=${vpc_id}" \
  -var "subnet_id=${subnet_id}" \
  ./xubuntu.pkr.hcl

cd ..

# ------------------------------------------------------------------------------
# Phase 3: Build the ALB, Guacamole and the servers
# ------------------------------------------------------------------------------
echo "NOTE: Building the ALB, Guacamole and server instances..."
 
cd 03-servers || { echo "ERROR: Directory 03-servers not found"; exit 1; }
 
terraform init
terraform apply -auto-approve
 
cd ..
 
# ------------------------------------------------------------------------------
# Build Validation
# ------------------------------------------------------------------------------
echo "NOTE: Running build validation..."
./validate.sh
 
echo "NOTE: Infrastructure build complete."
# ================================================================================
# End of Script
# ================================================================================
