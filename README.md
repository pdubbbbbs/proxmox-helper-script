# Proxmox Helper Script

A cross-platform PowerShell helper script for managing Proxmox VE environments.

## Features

- Cross-platform support (Windows, Linux, macOS)
- VM Management
- SSL Certificate handling
- Storage validation
- Network configuration
- Automated backups
- Security-focused design

## Current Server

Currently configured for: pve.sslgen.cam

## Requirements

- PowerShell Core 7.0 or higher
- Proxmox VE server access
- Administrative privileges (for certain operations)

## Installation

1. Clone this repository
2. Ensure PowerShell Core 7.0+ is installed
3. Set execution policy appropriately
4. Configure Proxmox server details

## Usage

Basic usage examples:

\\\powershell
# Connect to Proxmox server
./ProxmoxHelper.ps1 -Connect -Server 'pve.sslgen.cam' -Username 'root' -PasswordFile 'creds.xml'

# List all VMs
./ProxmoxHelper.ps1 -ListVMs

# Start a VM
./ProxmoxHelper.ps1 -StartVM -VMID 100
\\\

## License

MIT License - See LICENSE file for details

