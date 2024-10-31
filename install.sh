#!/bin/bash

# Install the required packages

function echo_message() {
    echo
    echo "----------------------------------------"
    echo $1
    echo "----------------------------------------"
    echo
}

function install_ssh_keys() {
    echo "Checking if SSH keys already exist..."
    if [ -f ~/.ssh/id_rsa ]; then
        echo "SSH keys already exist, do you wish to overwrite them? (y/n)"
        read response
        if [ "$response" != "n" ]; then
            echo "Skipping SSH key installation"
        return
        fi
    fi
    echo_message "Installing SSH keys"
    mkdir -p ~/.ssh
    ssh-keygen -b 4096 -t rsa -f ~/.ssh/id_rsa -q
    cp -r ssh/* ~/.ssh
    chmod 700 ~/.ssh
    chmod 600 ~/.ssh/*

    echo "SSH keys have been installed and can be accessed at ~/.ssh"
}

function network_setup() {
    echo_message "Setting up network configuration"
    echo "Enter hostname: "
    read hostname
    sudo hostnamectl set-hostname $hostname
    echo "Enter the IP address of the server: "
    read ip_address
    echo "Enter the gateway address: "
    read gateway
    echo "Enter the DNS server address: "
    read dns
    echo "Enter the network mask (e.g. CIDR, /24): "
    read mask

    cat <<EOF | sudo tee /etc/netplan/01-netcfg.yaml
network:
  version: 2
  ethernets:
    ens33:
      addresses:
      - $ip_address$mask
      nameservers:
        addresses:
        - $dns
        search: []
      routes:
      - to: default
        via: $gateway
EOF
 
    sudo netplan apply
}

function install_tenable_agent() {
    echo_message "Installing Tenable Agent"
    sudo curl -H 'X-Key: bbc23263c2474f1d856c5dbd62fea73778a6ed4b26ba34ac7b9c04b809b94317' "https://sensor.cloud.tenable.com/install/agent?name=$hostnamectl&groups=Server" | sudo bash
    sudo /opt/nessus_agent/sbin/nessuscli agent link --key=bbc23263c2474f1d856c5dbd62fea73778a6ed4b26ba34ac7b9c04b809b94317 --host=cloud.tenable.com --port=443
    echo
    echo "If you see an error stating the agent is already linked, ignore the error"
    echo "The agent has been installed and linked to your Tenable account"
}

function create_user() {
    echo_message "Creating a new user"
    echo "Enter the username: "
    read username
    sudo adduser $username
    sudo usermod -aG sudo $username
    echo "User $username has been created"
    echo "Create SSH keys for the new user? (y/n)"
    read response
    if [ "$response" == "y" ]; then
        sudo su - $username -c "ssh-keygen -b 4096 -t rsa -f ~/.ssh/id_rsa -q"
        sudo su - $username -c "cp -r ssh/* ~/.ssh"
        sudo su - $username -c "chmod 700 ~/.ssh"
        sudo su - $username -c "chmod 600 ~/.ssh/*"
        echo "SSH keys have been installed and can be accessed at ~/.ssh"
    fi
}

FLAG="/var/log/firstboot.log"
if [[ ! -f $FLAG ]]; then
    echo_message "Updating and installing basic system packages"

    sudo apt update && sudo apt upgrade -y

    create_user
    network_setup
    install_tenable_agent
    sudo ssh-keygen -A
    sudo service ssh restart
    touch "$FLAG"
else
    echo "Do nothing, first boot has already been completed"
fi

