#!/bin/bash

###############################################################################
#
# K3s Terraform Infrastructure Management Commands
# Author: Md Toriqul Islam
# Description: Reference commands for managing K3s Terraform infrastructure
# Note: This is a reference script. Do not execute directly.
#
###############################################################################

#------------------------------------------------------------------------------
# Terraform Infrastructure Management
#------------------------------------------------------------------------------

# Initialize Terraform workspace
terraform init

# Validate Terraform configuration
terraform validate

# Plan infrastructure changes
terraform plan -var-file="terraform.tfvars"

# Apply infrastructure changes
terraform apply -var-file="terraform.tfvars" -auto-approve

# Destroy infrastructure
terraform destroy -var-file="terraform.tfvars" -auto-approve

#------------------------------------------------------------------------------
# AWS Infrastructure Verification
#------------------------------------------------------------------------------

# List EC2 instances
aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=K3s*" \
    --query 'Reservations[].Instances[].{ID:InstanceId,Name:Tags[?Key==`Name`].Value|[0],State:State.Name}'

# Check VPC status
aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=K3s VPC" \
    --query 'Vpcs[].{VpcId:VpcId,State:State,Cidr:CidrBlock}'

#------------------------------------------------------------------------------
# K3s Cluster Management
#------------------------------------------------------------------------------

# SSH into master node
ssh -i "k3s-key.pem" ubuntu@<master-private-ip>

# Install K3s on master node
curl -sfL https://get.k3s.io | sh -

# Get K3s token
sudo cat /var/lib/rancher/k3s/server/node-token

# Join worker nodes
curl -sfL https://get.k3s.io | K3S_URL=https://<master-private-ip>:6443 K3S_TOKEN=<node-token> sh -

#------------------------------------------------------------------------------
# Cluster Verification
#------------------------------------------------------------------------------

# Check node status
sudo kubectl get nodes

# View cluster info
sudo kubectl cluster-info

# Check pod status
sudo kubectl get pods --all-namespaces

#------------------------------------------------------------------------------
# NGINX Load Balancer Configuration
#------------------------------------------------------------------------------

# SSH into NGINX instance
ssh -i "k3s-key.pem" ubuntu@<nginx-public-ip>

# Install NGINX
sudo apt update && sudo apt install nginx -y

# Check NGINX status
sudo systemctl status nginx

###############################################################################
# End of Command Reference
###############################################################################