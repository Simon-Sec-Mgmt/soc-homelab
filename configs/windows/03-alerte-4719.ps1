<#
.SYNOPSIS
    Envoie une notification ntfy quand la stratégie d'audit est modifiée (Event ID 4719).
.DESCRIPTION
    Lancé par la tâche planifiée "SOC\Alerte-4719" (déclencheur : Event ID 4719).
    Le sujet ntfy est lu dans un fichier local, jamais stocké dans le dépôt Git.
#>

$fichierSujet = "C:\SEC_MGMT_SCRIPTS\ntfy-topic.txt"
$journal      = "C:\SEC_MGMT_SCRIPTS\alerte-4719.log"

if (-not (Test-Path $fichierSujet)) { exit 1 }
$sujet = (Get-Content $fichierSujet -Raw).Trim()

# Dernier événement 4719 : qui a modifié quoi
$evt = Get-WinEvent -FilterHashtable @{ LogName = "Security"; Id = 4719 } -MaxEvents 1
$xml = [xml]$evt.ToXml()
$data = @{}
foreach ($d in $xml.Event.EventData.Data) { $data[$d.Name] = $d.'#text' }

$message = @"
Poste : $env:COMPUTERNAME
Heure : $($evt.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss"))
Compte : $($data["SubjectDomainName"])\$($data["SubjectUserName"])
Sous-catégorie : $($data["SubcategoryGuid"])
Changement : $($data["AuditPolicyChanges"])
"@

try {
    Invoke-RestMethod -Method Post -Uri "https://ntfy.sh/$sujet" -Body $message -Headers @{
        "Title"    = "Strategie d'audit modifiee (4719)"
        "Priority" = "high"
        "Tags"     = "warning,shield"
    }
    Add-Content $journal "$(Get-Date -Format s) Alerte envoyée"
}
catch {
    Add-Content $journal "$(Get-Date -Format s) Échec d'envoi : $($_.Exception.Message)"
}
