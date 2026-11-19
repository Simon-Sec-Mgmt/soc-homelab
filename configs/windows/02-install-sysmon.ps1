#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Télécharge et installe Sysmon avec la configuration de SwiftOnSecurity.
.NOTES
    À exécuter pendant la phase NAT (accès Internet requis).
    Sources : https://learn.microsoft.com/sysinternals/downloads/sysmon
              https://github.com/SwiftOnSecurity/sysmon-config
#>

$dossier = "C:\Tools\Sysmon"
New-Item -ItemType Directory -Path $dossier -Force | Out-Null

# Sysmon (Microsoft Sysinternals)
Invoke-WebRequest -Uri "https://download.sysinternals.com/files/Sysmon.zip" -OutFile "$dossier\Sysmon.zip"
Expand-Archive -Path "$dossier\Sysmon.zip" -DestinationPath $dossier -Force

# Configuration communautaire SwiftOnSecurity
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml" -OutFile "$dossier\sysmonconfig.xml"

# Installation du service et acceptation de la licence
& "$dossier\Sysmon64.exe" -accepteula -i "$dossier\sysmonconfig.xml"

Get-Service Sysmon64
