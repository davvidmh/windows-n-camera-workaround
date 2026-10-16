# Exercises control flow with mocked DISM, registry, and filesystem reads.
# Never invokes a real capability installation or changes the registry.
$ErrorActionPreference = 'Stop'
$scriptText = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\Repair-MediaFeaturePack.ps1') -Raw
$repairScript = [scriptblock]::Create($scriptText.Replace('#Requires -RunAsAdministrator', ''))

function Test-Scenario {
    param(
        [string]$Label,
        [string]$InitialState,
        [string]$FinalState = $InitialState,
        [bool]$RuntimePresent = $false,
        [bool]$RestartNeeded = $false,
        [switch]$Install,
        [switch]$Preview,
        [int]$ExpectedAdds = 0,
        [switch]$ExpectFailure
    )
    $scenario = @{ Reads = 0; Adds = 0 }
    function Get-ItemProperty {
        [CmdletBinding()] param([string]$LiteralPath)
        [pscustomobject]@{ EditionID = 'ProfessionalN'; CurrentBuild = '26200'; UBR = 9168 }
    }
    function Import-Module { [CmdletBinding()] param([string]$Name) }
    function Get-WindowsCapability {
        [CmdletBinding()] param([switch]$Online, [string]$Name)
        $scenario.Reads++
        $current = if ($scenario.Reads -eq 1) { $InitialState } else { $FinalState }
        [pscustomobject]@{ State = $current }
    }
    function Add-WindowsCapability {
        [CmdletBinding()]
        param([switch]$Online, [string]$Name, [switch]$LimitAccess, [string[]]$Source)
        if (-not $Online -or -not $LimitAccess -or $Name -ne 'Media.MediaFeaturePack~~~~0.0.1.0') {
            throw 'Unexpected servicing operation in test.'
        }
        $scenario.Adds++
        [pscustomobject]@{ RestartNeeded = $RestartNeeded }
    }
    function Test-Path {
        [CmdletBinding()] param([string]$LiteralPath, [string]$PathType)
        return $RuntimePresent
    }
    $failed = $false
    $result = $null
    try {
        $result = & $repairScript -Install:$Install -WhatIf:$Preview
    } catch {
        if ($_.Exception.Message -notlike 'No se pudo confirmar*') { throw }
        $failed = $true
    }
    if ($scenario.Adds -ne $ExpectedAdds) { throw "$Label : unexpected installation count" }
    if ($failed -ne [bool]$ExpectFailure) { throw "$Label : unexpected failure result" }
    if (-not $failed) {
        $expectedRestart = $RestartNeeded -or $FinalState -eq 'InstallPending'
        if ($result.RestartRequired -ne $expectedRestart) { throw "$Label : wrong restart status" }
    }
    Write-Host "PASS: $Label"
}

Test-Scenario -Label 'Read-only default' -InitialState Staged
Test-Scenario -Label 'Already installed' -InitialState Installed -RuntimePresent $true -Install
Test-Scenario -Label 'Already pending restart' -InitialState InstallPending -Install
Test-Scenario -Label 'Successful install pending restart is not a DLL failure' -InitialState Staged -FinalState InstallPending -RestartNeeded $true -Install -ExpectedAdds 1
Test-Scenario -Label 'Successful active installation' -InitialState Staged -FinalState Installed -RuntimePresent $true -Install -ExpectedAdds 1
Test-Scenario -Label 'WhatIf never installs' -InitialState Staged -Install -Preview
Test-Scenario -Label 'Silent non-installation must not report success' -InitialState Staged -Install -ExpectedAdds 1 -ExpectFailure
Test-Scenario -Label 'Installed but missing runtime must not report success' -InitialState Installed -Install -ExpectFailure
