# 03 — VM Windows : audit, Sysmon et agent Wazuh

**Objectif :** préparer un poste Windows qui produit des journaux riches et les envoie au serveur Wazuh.

## Création de la VM

| Paramètre | Valeur |
| --- | --- |
| OS | Windows 11 Entreprise, ISO d'évaluation gratuite (Microsoft Evaluation Center) |
| vCPU / RAM / disque | 2 / 4 Go / 60 Go |
| Carte réseau | NAT pendant l'installation, puis VMnet2 |
| Nom de l'ordinateur | `WIN-VICTIME` |
| Compte local | `labadmin` (administrateur) |

Après l'installation : installer les VMware Tools et les mises à jour Windows, **en NAT**.

## 1. Stratégie d'audit avancée

Par défaut, Windows ne journalise pas tout ce dont un analyste a besoin, par exemple les lignes de commande des processus. Le script [`01-auditpol-baseline.ps1`](../configs/windows/01-auditpol-baseline.ps1) active les sous-catégories utiles.

```powershell
# PowerShell en administrateur
Set-ExecutionPolicy -Scope Process Bypass
.\01-auditpol-baseline.ps1
```

Le script utilise les GUID des sous-catégories plutôt que leurs noms, parce que les noms changent selon la langue de Windows.

| Sous-catégorie | Événements générés |
| --- | --- |
| Validation des informations d'identification | 4776 |
| Ouverture de session / Fermeture de session | 4624, 4625, 4634 |
| Ouverture de session spéciale | 4672 |
| Verrouillage du compte | 4740 |
| Création de processus (+ ligne de commande) | 4688 |
| Modification de la stratégie d'audit | 4719 |
| Gestion des comptes d'utilisateurs | 4720, 4722, 4724, 4726 |
| Gestion des groupes de sécurité | 4728, 4732 |
| Extension système de sécurité | 4697 |

Le script agrandit aussi le journal Sécurité à 512 Mo pour éviter que les anciens événements soient écrasés trop vite.

## 2. Sysmon

Sysmon ajoute des événements que Windows ne fournit pas : connexions réseau par processus, hash des exécutables, chargements de pilotes, requêtes DNS.

Le script [`02-install-sysmon.ps1`](../configs/windows/02-install-sysmon.ps1) télécharge Sysmon et la configuration communautaire de SwiftOnSecurity, puis installe le service.

```powershell
.\02-install-sysmon.ps1
```

Vérification :

```powershell
Get-Service Sysmon64
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 5
```

## 3. Agent Wazuh

Le serveur Wazuh doit être joignable (VM SOC-WAZUH démarrée). Installer l'agent avec la **même version** que le manager :

```powershell
$version = "4.14.0-1"     # adapter à la version du manager
Invoke-WebRequest -Uri "https://packages.wazuh.com/4.x/windows/wazuh-agent-$version.msi" -OutFile "$env:TEMP\wazuh-agent.msi"
msiexec.exe /i "$env:TEMP\wazuh-agent.msi" /q WAZUH_MANAGER="10.10.10.10" WAZUH_AGENT_NAME="WIN-VICTIME"
```

Le dashboard Wazuh (**Agents → Deploy new agent**) génère aussi cette commande avec la version exacte.

### Ajout des journaux Sysmon à l'agent

Par défaut, l'agent Windows ne lit pas le journal Sysmon. Ajouter le bloc de [`configs/wazuh/agent-localfile.xml`](../configs/wazuh/agent-localfile.xml) dans :

```
C:\Program Files (x86)\ossec-agent\ossec.conf
```

juste avant la balise de fermeture `</ossec_config>`, puis démarrer l'agent :

```powershell
NET START WazuhSvc
```

## 4. Passage en IP fixe sur VMnet2

1. Éteindre la VM, carte réseau → **VMnet2**, redémarrer.
2. Configurer l'IP :

```powershell
$if = (Get-NetAdapter | Where-Object Status -eq "Up").Name
New-NetIPAddress -InterfaceAlias $if -IPAddress 10.10.10.20 -PrefixLength 24
```

3. Redémarrer l'agent pour qu'il se reconnecte : `Restart-Service WazuhSvc`.

## Vérification

- [ ] `auditpol /get /category:*` montre les sous-catégories activées
- [ ] Le service `Sysmon64` est en cours d'exécution
- [ ] `Test-NetConnection 10.10.10.10 -Port 1514` → `TcpTestSucceeded : True`
- [ ] Dans le dashboard, l'agent `WIN-VICTIME` est **Active**
- [ ] Des événements Sysmon apparaissent dans **Threat Hunting** (filtre `data.win.system.channel: Microsoft-Windows-Sysmon/Operational`)
