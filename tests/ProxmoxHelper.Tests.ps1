# Test suite for Proxmox Helper Script
# Requires Pester v5.0 or later

BeforeAll {
    # Import module
    Import-Module (Join-Path $PSScriptRoot '..' 'ProxmoxHelper.psd1') -Force
    
    # Mock configuration
    $mockServer = 'pve.sslgen.cam'
    $mockPort = 8006
    $mockUsername = 'root@pam'
    $mockPassword = ConvertTo-SecureString 'MockPassword' -AsPlainText -Force
}

Describe 'Core Module Tests' {
    Context 'Module Loading' {
        It 'Module should be loaded' {
            Get-Module ProxmoxHelper | Should -Not -BeNull
        }
        
        It 'Should export required functions' {
            @(
                'Connect-ProxmoxServer',
                'Disconnect-ProxmoxServer',
                'Invoke-ProxmoxAPI',
                'Write-Log',
                'Test-Administrator'
            ) | ForEach-Object {
                Get-Command -Name $_ -Module ProxmoxHelper | Should -Not -BeNull
            }
        }
    }
    
    Context 'Configuration Management' {
        BeforeAll {
            $testConfigName = 'TestConfig'
            $testConfigPath = Join-Path $TestDrive "$testConfigName.json"
        }
        
        It 'Should create new configuration' {
            Set-ProxmoxConfig -ConfigName $testConfigName 
                            -Server $mockServer 
                            -Port $mockPort 
                            -Username $mockUsername 
                            -ErrorAction Stop
            
            Get-ProxmoxConfig -ConfigName $testConfigName | Should -Not -BeNull
        }
        
        It 'Should update existing configuration' {
            Set-ProxmoxConfig -ConfigName $testConfigName 
                            -LogLevel 'Debug' 
                            -ErrorAction Stop
            
            $config = Get-ProxmoxConfig -ConfigName $testConfigName
            $config.Settings.LogLevel | Should -Be 'Debug'
        }
        
        It 'Should remove configuration' {
            Remove-ProxmoxConfig -ConfigName $testConfigName -ErrorAction Stop
            Get-ProxmoxConfig -ConfigName $testConfigName | Should -BeNull
        }
    }
}

Describe 'SSL Management Tests' {
    Context 'Certificate Generation' {
        BeforeAll {
            $testDomain = 'test.example.com'
            $testEmail = 'test@example.com'
        }
        
        It 'Should generate self-signed certificate' {
            $cert = New-ProxmoxSSLCertificate -Domain $testDomain 
                                             -Email $testEmail 
                                             -Type SelfSigned 
                                             -ErrorAction Stop
            
            $cert | Should -Not -BeNull
            $cert.Certificate | Should -Not -BeNull
            Test-Path $cert.PfxPath | Should -Be $true
            Test-Path $cert.CertPath | Should -Be $true
        }
    }
}

Describe 'VM Management Tests' {
    Context 'VM Operations' {
        BeforeAll {
            Mock Invoke-ProxmoxAPI {
                return @{
                    vmid = 100
                    name = 'test-vm'
                    status = 'running'
                }
            }
        }
        
        It 'Should get VM information' {
            $vm = Get-ProxmoxVM -VMID 100 -ErrorAction Stop
            $vm | Should -Not -BeNull
            $vm.vmid | Should -Be 100
            $vm.name | Should -Be 'test-vm'
        }
        
        It 'Should create new VM' {
            $vm = New-ProxmoxVM -Name 'test-vm' 
                                -Memory 2048 
                                -Cores 2 
                                -ErrorAction Stop
            
            $vm | Should -Not -BeNull
            $vm.name | Should -Be 'test-vm'
        }
    }
}

Describe 'Network Management Tests' {
    Context 'Network Operations' {
        BeforeAll {
            Mock Invoke-ProxmoxAPI {
                return @{
                    iface = 'vmbr0'
                    type = 'bridge'
                    active = $true
                }
            }
        }
        
        It 'Should get network information' {
            $network = Get-ProxmoxNetwork -ErrorAction Stop
            $network | Should -Not -BeNull
            $network.iface | Should -Be 'vmbr0'
            $network.type | Should -Be 'bridge'
        }
    }
}

Describe 'Storage Management Tests' {
    Context 'Storage Operations' {
        BeforeAll {
            Mock Invoke-ProxmoxAPI {
                return @{
                    storage = 'local'
                    type = 'dir'
                    active = 1
                }
            }
        }
        
        It 'Should get storage information' {
            $storage = Get-ProxmoxStorage -ErrorAction Stop
            $storage | Should -Not -BeNull
            $storage.storage | Should -Be 'local'
            $storage.type | Should -Be 'dir'
        }
    }
}

Describe 'Monitoring Tests' {
    Context 'Monitoring Operations' {
        BeforeAll {
            Mock Invoke-ProxmoxAPI {
                return @{
                    status = 'running'
                    quorum = 1
                    nodes = @(
                        @{
                            node = 'node1'
                            status = 'online'
                        }
                    )
                }
            }
        }
        
        It 'Should get cluster status' {
            $status = Get-ProxmoxClusterStatus -ErrorAction Stop
            $status | Should -Not -BeNull
            $status.status | Should -Be 'running'
            $status.quorum | Should -Be 1
        }
        
        It 'Should perform health check' {
            $health = Test-ProxmoxHealth -ErrorAction Stop
            $health | Should -Not -BeNull
            $health.Status | Should -Be 'Healthy'
        }
    }
}
