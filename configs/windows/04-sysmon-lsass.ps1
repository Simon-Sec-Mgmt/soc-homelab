<#
.SYNOPSIS
    Active la journalisation Sysmon des accès à LSASS (Event ID 10).
.DESCRIPTION
    La configuration SwiftOnSecurity désactive l'EID 10 (ProcessAccess) parce qu'il est très bruyant.
    Ce script crée une copie de la configuration où seul l'accès à lsass.exe est journalisé,
    en excluant Microsoft Defender, puis l'applique à Sysmon.
    La configuration d'origine n'est pas modifiée.
.NOTES
    Prérequis : 02-install-sysmon.ps1 déjà exécuté.
    À lancer dans PowerShell en administrateur.
    Voir docs/08-detection-lsass.md
#>

$dossier  = "C:\Tools\Sysmon"
$original = "$dossier\sysmonconfig.xml"
$modifiee = "$dossier\sysmonconfig-lsass.xml"

if (-not (Test-Path $original)) {
    Write-Error "Configuration introuvable : $original. Lancer d'abord 02-install-sysmon.ps1."
    exit 1
}

$xml = Get-Content $original -Raw

# Bloc vide de l'EID 10 dans la configuration SwiftOnSecurity
$motif = '(?s)<ProcessAccess onmatch="include">.*?</ProcessAccess>\s*</RuleGroup>'

$remplacement = @'
<ProcessAccess onmatch="include">
			<TargetImage name="T1003.001,LSASS" condition="is">C:\Windows\system32\lsass.exe</TargetImage>
		</ProcessAccess>
	</RuleGroup>
	<RuleGroup name="" groupRelation="or">
		<ProcessAccess onmatch="exclude">
			<SourceImage condition="end with">MsMpEng.exe</SourceImage>
		</ProcessAccess>
	</RuleGroup>
'@

$trouves = [regex]::Matches($xml, $motif).Count
if ($trouves -ne 1) {
    Write-Error "Bloc ProcessAccess attendu une seule fois, trouvé $trouves fois. Configuration non modifiée."
    exit 1
}

$xml = [regex]::Replace($xml, $motif, $remplacement)
Set-Content -Path $modifiee -Value $xml -Encoding UTF8

# Application de la nouvelle configuration
& "$dossier\Sysmon64.exe" -c $modifiee

Write-Host "Configuration appliquée : $modifiee"
Write-Host "Vérification : & '$dossier\Sysmon64.exe' -c | Select-String -Context 0,3 ProcessAccess"