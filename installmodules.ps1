# PowerShell script to install all Azure Az modules

# Ensure script runs with admin privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Please run this script as Administrator."
    exit
}

# Set TLS version to avoid connection issues with older protocols
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Check if NuGet provider is available
if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
    Write-Host "Installing NuGet provider..." -ForegroundColor Yellow
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
}

# Ensure latest version of PowerShellGet is installed
Write-Host "Installing/Updating PowerShellGet..." -ForegroundColor Yellow
Install-Module -Name PowerShellGet -Force -AllowClobber

# Install Az module (includes all submodules)
Write-Host "Installing Az module (this includes all Azure PowerShell modules)..." -ForegroundColor Green
Install-Module -Name Az -AllowClobber -Scope AllUsers -Force

# Confirm installed modules
Write-Host "`nInstalled Az modules:" -ForegroundColor Cyan
Get-Module -ListAvailable -Name Az* | Select-Object Name, Version | Sort-Object Name
