# InstallMEADataOrgCert.ps1
param(
  [string]$CertPath
)

# === 0) Auto-discover the .cer if none supplied ===
if (-not $CertPath) {
  $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
  $cerFiles  = Get-ChildItem -Path $scriptDir -Filter '*.cer' -File

  switch ($cerFiles.Count) {
    0 {
      Write-Error "No .cer file found in folder '$scriptDir'. Please place exactly one .cer here or pass -CertPath."
      exit 1
    }
    1 {
      $CertPath = $cerFiles[0].FullName
      Write-Host "Auto-found certificate:`n  $CertPath"
    }
    default {
      Write-Error "Multiple .cer files found in '$scriptDir'. Either remove extras or specify -CertPath manually."
      exit 1
    }
  }
}

# === 1) Require elevation ===
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
       ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Error "This script must be run as Administrator."
  exit 1
}

# === 2) Load the certificate ===
try {
  $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertPath)
} catch {
  Write-Error "Failed to load certificate at '$CertPath': $_"
  exit 1
}

# === 3) Helper to add only if missing ===
function Add-CertIfMissing($storeName, $storeLocation, $cert) {
  $store = New-Object System.Security.Cryptography.X509Certificates.X509Store($storeName, $storeLocation)
  $store.Open('ReadWrite')
  if (-not ($store.Certificates | Where-Object Thumbprint -eq $cert.Thumbprint)) {
    $store.Add($cert)
    Write-Host "Added cert to $storeName`:$storeLocation"
  } else {
    Write-Host "Cert already present in $storeName`:$storeLocation"
  }
  $store.Close()
}

# === 4) Install into the two stores ===
Add-CertIfMissing Root             LocalMachine $cert
Add-CertIfMissing TrustedPublisher LocalMachine $cert

# === 5) Report ===
Write-Host "Installed cert with subject: $($cert.Subject)"
Write-Host "Thumbprint:          $($cert.Thumbprint)"
