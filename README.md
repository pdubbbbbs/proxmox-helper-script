# Proxmox Helper Script

[![Test and Coverage](https://github.com/pdubbbbbs/proxmox-helper-script/actions/workflows/test.yml/badge.svg)](https://github.com/pdubbbbbs/proxmox-helper-script/actions/workflows/test.yml)
[![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/ProxmoxHelper)](https://www.powershellgallery.com/packages/ProxmoxHelper)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/ProxmoxHelper)](https://www.powershellgallery.com/packages/ProxmoxHelper)
[![License](https://img.shields.io/github/license/pdubbbbbs/proxmox-helper-script)](LICENSE)

A cross-platform PowerShell helper script for managing Proxmox VE environments, providing comprehensive tools for VM management, SSL certificates, storage, networking, and monitoring.

## Features

- 🖥️ **VM Management**: Create, modify, and manage virtual machines
- 🔒 **SSL Certificates**: Generate and deploy SSL certificates
- 💾 **Storage Management**: Handle storage pools, backups, and snapshots
- 🌐 **Network Configuration**: Manage network settings and firewall rules
- 📊 **Monitoring**: Track system health and performance
- ⚙️ **Configuration**: Flexible configuration management
- 🔄 **Cross-Platform**: Works on Windows, Linux, and macOS

## Quick Start

```powershell
# Install from PowerShell Gallery
Install-Module -Name ProxmoxHelper -Scope CurrentUser

# Import module
Import-Module ProxmoxHelper

# Connect to Proxmox server
Connect-ProxmoxServer -Server "pve.sslgen.cam" -Username "root@pam"
```

See [QUICKSTART.md](QUICKSTART.md) for detailed setup instructions.

## Documentation

- [Quick Start Guide](QUICKSTART.md)
- [Examples](examples/README.md)
- [Contributing](CONTRIBUTING.md)
- [Security](SECURITY.md)
- [Changelog](CHANGELOG.md)

## Requirements

- PowerShell 7.0 or higher
- Proxmox VE server access
- Administrative privileges (for certain operations)

## Installation

### From PowerShell Gallery
```powershell
Install-Module -Name ProxmoxHelper -Scope CurrentUser
```

### From GitHub
```powershell
git clone https://github.com/pdubbbbbs/proxmox-helper-script.git
cd proxmox-helper-script
Import-Module ./ProxmoxHelper.psd1
```

## Usage Examples

See [examples](examples/README.md) for detailed usage scenarios.

## Contributing

Contributions are welcome! Please read our [Contributing Guidelines](CONTRIBUTING.md) before submitting a pull request.

## Security

For security-related information and guidelines, see our [Security Policy](SECURITY.md).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Proxmox VE team for their excellent platform
- PowerShell team for cross-platform support
- Community contributors

## Support

- Report bugs via [GitHub Issues](https://github.com/pdubbbbbs/proxmox-helper-script/issues)
- Request features through [GitHub Discussions](https://github.com/pdubbbbbs/proxmox-helper-script/discussions)
- Get help in our [GitHub Discussions](https://github.com/pdubbbbbs/proxmox-helper-script/discussions)
