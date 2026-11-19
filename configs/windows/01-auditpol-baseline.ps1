#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Applique la stratégie d'audit avancée de référence du labo SOC.
.DESCRIPTION
    Les sous-catégories sont désignées par leur GUID, car leurs noms
    dépendent de la langue de Windows (français ou anglais).
#>

$subcategories = @(
    @{ Nom = "Validation des informations d'identification"; Guid = "{0CCE923F-69AE-11D9-BED3-505054503030}"; Succes = $true;  Echec = $true  },
    @{ Nom = "Ouverture de session";                         Guid = "{0CCE9215-69AE-11D9-BED3-505054503030}"; Succes = $true;  Echec = $true  },
    @{ Nom = "Fermeture de session";                         Guid = "{0CCE9216-69AE-11D9-BED3-505054503030}"; Succes = $true;  Echec = $false },
    @{ Nom = "Verrouillage du compte";                       Guid = "{0CCE9217-69AE-11D9-BED3-505054503030}"; Succes = $true;  Echec = $true  },
    @{ Nom = "Ouverture de session spéciale";                Guid = "{0CCE921B-69AE-11D9-BED3-505054503030}"; Succes = $true;  Echec = $false },
    @{ Nom = "Création du processus";                        Guid = "{0CCE922B-69AE-11D9-BED3-505054503030}"; Succes = $true;  Echec = $false },
    @{ Nom = "Modification de la stratégie d'audit";         Guid = "{0CCE922F-69AE-11D9-BED3-505054503030}"; Succes = $true;  Echec = $true  },
    @{ Nom = "Gestion des comptes d'utilisateurs";           Guid = "{0CCE9235-69AE-11D9-BED3-505054503030}"; Succes = $true;  Echec = $true  },
    @{ Nom = "Gestion des groupes de sécurité";              Guid = "{0CCE9237-69AE-11D9-BED3-505054503030}"; Succes = $true;  Echec = $true  },
    @{ Nom = "Extension système de sécurité";                Guid = "{0CCE9211-69AE-11D9-BED3-505054503030}"; Succes = $true;  Echec = $true  }
)

foreach ($s in $subcategories) {
    $succes = if ($s.Succes) { "enable" } else { "disable" }
    $echec  = if ($s.Echec)  { "enable" } else { "disable" }
    auditpol /set /subcategory:"$($s.Guid)" /success:$succes /failure:$echec | Out-Null
    Write-Host "[OK] $($s.Nom)"
}

# Inclure la ligne de commande complète dans les événements 4688
$reg = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit"
New-Item -Path $reg -Force | Out-Null
Set-ItemProperty -Path $reg -Name "ProcessCreationIncludeCmdLine_Enabled" -Value 1 -Type DWord
Write-Host "[OK] Ligne de commande incluse dans l'événement 4688"

# Forcer l'utilisation des sous-catégories avancées plutôt que des catégories de base
$lsa = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
Set-ItemProperty -Path $lsa -Name "SCENoApplyLegacyAuditPolicy" -Value 1 -Type DWord
Write-Host "[OK] Stratégie d'audit avancée prioritaire"

# Agrandir le journal Sécurité à 512 Mo
wevtutil sl Security /ms:536870912
Write-Host "[OK] Journal Sécurité : 512 Mo"

Write-Host "`nVérification : auditpol /get /category:*"
