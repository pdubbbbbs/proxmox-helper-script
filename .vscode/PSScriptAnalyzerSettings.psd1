@{
    Severity = @('Error', 'Warning', 'Information')
    IncludeDefaultRules = $true
    
    Rules = @{
        PSAvoidUsingCmdletAliases = @{
            Enable = $true
        }
        PSAvoidUsingPositionalParameters = @{
            Enable = $true
        }
        PSUseCompatibleCmdlets = @{
            Enable = $true
            Compatibility = @('desktop-5.1.14393.206-windows', 'core-6.1.0-windows', 'core-6.1.0-linux', 'core-6.1.0-macos')
        }
        PSUseDeclaredVarsMoreThanAssignments = @{
            Enable = $true
        }
        PSUseConsistentIndentation = @{
            Enable = $true
        }
        PSUseConsistentWhitespace = @{
            Enable = $true
        }
        PSAlignAssignmentStatement = @{
            Enable = $true
        }
        PSUseCorrectCasing = @{
            Enable = $true
        }
    }
}
