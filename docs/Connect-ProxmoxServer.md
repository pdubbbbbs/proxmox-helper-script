---
external help file: ProxmoxHelper-help.xml
Module Name: ProxmoxHelper
online version: https://github.com/pdubbbbbs/proxmox-helper-script
schema: 2.0.0
---

# Connect-ProxmoxServer

## SYNOPSIS
Connects to a Proxmox VE server.

## SYNTAX

```powershell
Connect-ProxmoxServer [-Server] <String> [-Port <Int32>] [-Username <String>] [-Password <SecureString>]
 [-PasswordFile <String>] [-SkipCertificateCheck] [<CommonParameters>]
```

## DESCRIPTION
Establishes a connection to a Proxmox VE server using the provided credentials. This cmdlet must be called before using other module functions.

## EXAMPLES

### Example 1
```powershell
Connect-ProxmoxServer -Server "pve.sslgen.cam" -Username "root@pam"
```

Connects to the Proxmox server using the specified credentials.

### Example 2
```powershell
Connect-ProxmoxServer -Server "pve.sslgen.cam" -Port 8006 -PasswordFile "credentials.xml"
```

Connects to the Proxmox server using stored credentials.

## PARAMETERS

### -Server
The hostname or IP address of the Proxmox server.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Port
The port number for the Proxmox API (default: 8006).

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 8006
Accept pipeline input: False
Accept wildcard characters: False
```

### -Username
The username to authenticate with.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Password
The password as a SecureString.

```yaml
Type: SecureString
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PasswordFile
Path to a file containing stored credentials.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SkipCertificateCheck
Skip SSL certificate validation.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

## INPUTS

### None

## OUTPUTS

### System.Boolean
Returns True if the connection is successful.

## NOTES
This cmdlet must be called before using other module functions.

## RELATED LINKS
https://github.com/pdubbbbbs/proxmox-helper-script
