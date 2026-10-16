#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
Inspects or installs the Windows N Media Feature Pack using local sources.
.DESCRIPTION
Default: read-only diagnostics. Use -Install to install the specific capability.
Never downloads from Windows Update, restarts Windows, or removes capabilities.
.EXAMPLE
.\Repair-MediaFeaturePack.ps1 -Install -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [switch]$Install,
    [string[]]$Source
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$capabilityName = 'Media.MediaFeaturePack~~~~0.0.1.0'

if ([IntPtr]::Size -ne 8) {
    throw 'Use Windows PowerShell de 64 bits como administrador.'
}

$windowsVersion = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
if ($windowsVersion.EditionID -notmatch 'N$') {
    throw 'Este workaround es para ediciones Windows N. No se realizo ningun cambio.'
}

Import-Module Dism -ErrorAction Stop
$runtimePath = Join-Path $env:windir 'System32\mfplat.dll'
$capability = Get-WindowsCapability -Online -Name $capabilityName -ErrorAction Stop
$installRestartNeeded = $false

if ($Install -and $capability.State.ToString() -notin @('Installed', 'InstallPending')) {
    if ($PSCmdlet.ShouldProcess($capabilityName, 'Instalar usando archivos locales, sin consultar Windows Update')) {
        $installArguments = @{
            Online = $true
            Name = $capabilityName
            LimitAccess = $true
            ErrorAction = 'Stop'
        }
        if ($Source) {
            foreach ($sourcePath in $Source) {
                if (-not (Test-Path -LiteralPath $sourcePath -PathType Container)) {
                    throw "El origen no es una carpeta accesible: $sourcePath"
                }
            }
            $installArguments.Source = $Source
        }
        $installResult = Add-WindowsCapability @installArguments
        $installRestartNeeded = [bool]$installResult.RestartNeeded
        $capability = Get-WindowsCapability -Online -Name $capabilityName -ErrorAction Stop
    }
}

$state = $capability.State.ToString()
$runtimePresent = Test-Path -LiteralPath $runtimePath -PathType Leaf
$restartRequired = $installRestartNeeded -or $state -eq 'InstallPending'

[pscustomobject]@{
    Edition = $windowsVersion.EditionID
    Build = '{0}.{1}' -f $windowsVersion.CurrentBuild, $windowsVersion.UBR
    CapabilityState = $state
    RuntimePresent = $runtimePresent
    RestartRequired = $restartRequired
}

if ($restartRequired) {
    Write-Host 'La operacion requiere reiniciar. Guarde su trabajo y reinicie manualmente.'
    Write-Host 'Despues, vuelva a consultar el estado y pruebe una foto real.'
} elseif ($state -eq 'Installed' -and $runtimePresent) {
    Write-Host 'El componente esta instalado. Falta comprobar la webcam con una captura real.'
} elseif ($Install -and -not $WhatIfPreference) {
    throw 'No se pudo confirmar la instalacion. Revise el estado y los registros DISM/CBS; no repita automaticamente.'
} else {
    Write-Host 'Diagnostico terminado. Use -Install para intentar la instalacion local.'
}
