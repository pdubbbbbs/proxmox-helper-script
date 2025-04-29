# SSL Certificate Management Module
# Part of Proxmox Helper Script

function New-ProxmoxSSLCertificate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Domain,

        [Parameter(Mandatory = $true)]
        [string]$Email,

        [Parameter()]
        [ValidateSet('LetsEncrypt', 'SelfSigned')]
        [string]$Type = 'SelfSigned',

        [Parameter()]
        [string]$CertPath = (Join-Path $script:CertPath $Domain)
    )

    begin {
        if (-not (Test-Path $CertPath)) {
            New-Item -ItemType Directory -Path $CertPath -Force | Out-Null
        }
    }

    process {
        Write-Log "Generating SSL certificate for $Domain" -Level Info

        switch ($Type) {
            'LetsEncrypt' {
                # Implement Let's Encrypt certificate generation
                throw 'Let''s Encrypt implementation pending'
            }
            'SelfSigned' {
                try {
                    $certParams = @{
                        DnsName = $Domain
                        CertStoreLocation = 'Cert:\CurrentUser\My'
                        NotAfter = (Get-Date).AddYears(1)
                        KeyLength = 2048
                        KeyAlgorithm = 'RSA'
                        HashAlgorithm = 'SHA256'
                        KeyUsage = 'DigitalSignature', 'KeyEncipherment'
                        TextExtension = @(
                            '2.5.29.37={text}1.3.6.1.5.5.7.3.1'
                            '2.5.29.37={text}1.3.6.1.5.5.7.3.2'
                        )
                    }

                    $cert = New-SelfSignedCertificate @certParams
                    
                    # Export certificate and private key
                    $pfxPassword = ConvertTo-SecureString -String (New-Guid).ToString() -Force -AsPlainText
                    $pfxPath = Join-Path $CertPath 'certificate.pfx'
                    $cert | Export-PfxCertificate -FilePath $pfxPath -Password $pfxPassword

                    # Export public certificate
                    $certPath = Join-Path $CertPath 'certificate.cer'
                    $cert | Export-Certificate -FilePath $certPath -Type CERT

                    Write-Log "Self-signed certificate generated successfully for $Domain" -Level Success
                    return @{
                        Certificate = $cert
                        PfxPath = $pfxPath
                        CertPath = $certPath
                        Password = $pfxPassword
                    }
                }
                catch {
                    Write-Log "Failed to generate self-signed certificate: $_" -Level Error
                    throw
                }
            }
        }
    }
}

function Install-ProxmoxSSLCertificate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Domain,

        [Parameter(Mandatory = $true)]
        [string]$CertPath,

        [Parameter()]
        [SecureString]$Password
    )

    process {
        Write-Log "Installing SSL certificate for $Domain" -Level Info

        try {
            # Implement certificate installation to Proxmox
            throw 'Certificate installation implementation pending'
        }
        catch {
            Write-Log "Failed to install certificate: $_" -Level Error
            throw
        }
    }
}

function Test-SSLCertificate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Domain,

        [Parameter()]
        [int]$Port = 8006
    )

    process {
        try {
            $cert = $null
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $tcpClient.Connect($Domain, $Port)

            $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream())
            $sslStream.AuthenticateAsClient($Domain)
            $cert = $sslStream.RemoteCertificate

            if ($cert) {
                $certInfo = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($cert)
                return @{
                    Subject = $certInfo.Subject
                    Issuer = $certInfo.Issuer
                    ValidFrom = $certInfo.NotBefore
                    ValidTo = $certInfo.NotAfter
                    Thumbprint = $certInfo.Thumbprint
                    SerialNumber = $certInfo.SerialNumber
                }
            }
        }
        catch {
            Write-Log "Failed to test SSL certificate: $_" -Level Error
            return $null
        }
        finally {
            if ($sslStream) { $sslStream.Dispose() }
            if ($tcpClient) { $tcpClient.Dispose() }
        }
    }
}
