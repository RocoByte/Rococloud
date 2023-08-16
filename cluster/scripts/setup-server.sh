#!/bin/bash

################################################################################
# Script: RocoCloud Host Setup Script
# Description: This script is used to prepare a host for connection to the RocoCloud cluster.
#              It sets up the hostname, installs necessary software, configures Docker,
#              and mounts an NFS share for storage.
# Author: Rocobyte
#
# Config example:
# swarm_token="YOUR_SWARM_TOKEN"
# swarm_ip_address="YOUR_IP_ADDRESS"
# storage_ip_address="YOUR_IP_ADDRESS"
# location="YOUR_LOCATION"
################################################################################

# Define color codes
RED='\033[0;31m'
NC='\033[0m'

# Get the directory of the script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Check if the configuration file exists
CONFIG_FILE="$SCRIPT_DIR/swarm_config.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error:${NC} Configuration file $CONFIG_FILE not found."
    exit 1
fi

# Read configuration from the file
source "$SCRIPT_DIR/swarm_config.conf" || { echo -e "${RED}Error:${NC} Unable to source configuration file $CONFIG_FILE"; exit 1; }

# Inform the user that the host is being prepared
echo "Preparing this host for use. This may take a moment."

# Backup the original hostname if not already done
if [ ! -e "/etc/hostname.init" ]; then
   cp /etc/hostname /etc/hostname.init
fi

# Retrieve the original hostname
hostname=$(cat /etc/hostname.init)

# Set the new hostname with the domain suffix
echo "${hostname}.rococloud.me" > /etc/hostname

# Inform the user about the hostname change
echo "Hostname has been changed to $(cat /etc/hostname)"

# Update and upgrade the system
echo "Installing updates and upgrades..."
apt-get update > /dev/null && apt-get upgrade -y > /dev/null && apt install sudo -y > /dev/null 2>&1
echo "Updates and upgrades installed."

# Install required software
echo "Installing required software..."
sudo apt-get install ca-certificates curl gnupg -y > /dev/null 2>&1
echo "Required software installed."

# Install Docker GPG key and repository
echo "Installing Docker GPG key and repository..."
sudo install -m 0755 -d /etc/apt/keyrings > /dev/null 2>&1
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes > /dev/null 2>&1
sudo chmod a+r /etc/apt/keyrings/docker.gpg > /dev/null 2>&1
echo "Docker GPG key and repository installed."

# Add Docker repository to sources list
echo "Adding Docker repository to sources..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
echo "Docker repository added to sources."

# Install Docker and related packages
echo "Installing Docker and related packages..."
sudo apt-get update -y > /dev/null
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y > /dev/null 2>&1
echo "Docker and related packages installed."

# Check if Docker installation was successful
dockerInfo=$(docker -v)
if expr "$dockerInfo" : "Docker version" > /dev/null; then
   echo "Docker has been successfully installed. The host is now prepared for connection to the cluster and will restart once after successful setup."

   # Create connection script for swarm cluster
   echo "Creating connection script for swarm cluster..."
   {
       echo "sleep 5"
       echo "docker swarm join --token $swarm_token $swarm_ip_address"
       echo "crontab -r"
       echo "rm -r /root/connect.sh"
   } > /root/connect.sh

   # Add connection script to crontab
   crontab -r > /dev/null
   chmod 777 /root/connect.sh > /dev/null 2>&1
   {
       crontab -l 2>/dev/null
       echo "@reboot /root/connect.sh"
   } | crontab -

   # Handle connection to storage sharepoint
   echo "Installing NFS packages and configuring storage sharepoint..."
   apt install nfs-kernel-server nfs-common -y > /dev/null

   # Create directory with the name based on the location
   storage_directory="/storage/$location"
   mkdir -p "$storage_directory"

   # Add connection string to fstab
   echo "$nfs_ip_address:/$location        $storage_directory   nfs auto,nofail,noatime,nolock,intr,tcp,actimeo=1800 0 0" >> /etc/fstab

   # Mount NFS share and check if successful
   if mount -a; then
       echo "NFS share successfully mounted."
   else
       echo -e "${RED}Failed:${NC} to mount NFS share."
   fi

   # Reboot the system
   echo "Preparation complete. Rebooting the system..."
   reboot
else
   echo -e "${RED}Error:${NC} Docker could not be found on this host. The installation does not appear to have been successful."
fi
