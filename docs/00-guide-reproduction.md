# SOC Homelab — Guide de reproduction

Nov 19, 2026 · @Simon

## En bref

Ce guide permet de remonter le labo SOC à l'identique sur ton propre PC : un serveur Wazuh, un poste Windows surveillé et une Kali attaquante, isolés sur un réseau virtuel. Compte environ une journée de montage, surtout en téléchargements et mises à jour.

À la fin, tu auras :

- un SIEM Wazuh 4.14 qui reçoit les journaux Windows et Sysmon d'un agent actif ;
- une stratégie d'audit Windows durcie et une alerte mobile (ntfy) sur l'événement 4719 ;
- trois snapshots `00-baseline` identiques aux miens, pour qu'on lance les mêmes scénarios et qu'on compare nos détections.

Les scripts et procédures détaillées sont dans le dépôt GitHub `Simon-Sec-Mgmt/soc-homelab` (`docs/01` à `docs/07`, `configs/`). Ce guide en est le fil conducteur. Le dépôt n'est pas public : demande-moi de t'ajouter comme collaborateur.

## Architecture

&#91;embedded content: architecture du labo · 3 VM sur VMnet2\]

WIN-VICTIME envoie ses journaux à SOC-WAZUH ; KALI attaque uniquement WIN-VICTIME ; l'hôte ne sert qu'à consulter le dashboard. Les RAM indiquées sont celles du budget 16 Go. Sur mon PC, les VM s'appellent encore `ubuntuSRV_Wazuh`, `win11_target` et `kali` : utilise les noms du schéma, qui sont ceux du dépôt.

## Prérequis

Le labo tourne sur un PC de 16 Go de RAM à condition de suivre le budget mémoire ci-dessous ; avec 32 Go, garde les valeurs « confort ».

### Matériel et logiciels

| Élément | Minimum | Notes |
| --- | --- | --- |
| RAM de l'hôte | 16 Go | 32 Go recommandés |
| Disque | \~190 Go libres sur SSD | Plus les snapshots |
| CPU | 4 cœurs avec VT-x activé dans le BIOS | Le mien : i5-13400F |
| Hyperviseur | VMware Workstation Pro | Gratuit pour usage personnel |
| ISO Ubuntu | Ubuntu Server 24.04 LTS | ubuntu.com |
| ISO Windows | Windows 11 Entreprise, évaluation 90 jours | Microsoft Evaluation Center |
| Kali | Image VMware préconstruite | kali.org |
| Téléphone | Appli ntfy | Pour l'alerte 4719 |

### Budget mémoire

| VM | RAM à 16 Go | RAM confort (32 Go) | vCPU | Disque |
| --- | --- | --- | --- | --- |
| SOC-WAZUH | 4 Go, heap indexeur 1 Go | 8 Go | 4 | 50 Go |
| WIN-VICTIME | 4 Go à l'installation, puis 3 Go | 4 Go | 2 | 60 Go |
| KALI | 2 Go, sans bureau pendant les attaques | 4 Go | 2 | 80 Go |

La plupart du temps, seules SOC-WAZUH et WIN-VICTIME tournent. Kali ne s'allume que pour les scénarios réseau. Dans VMware : **Edit → Preferences → Memory → Allow some virtual machine memory to be swapped**. Détails dans `docs/07-contrainte-16go-ram.md`.

### Arborescence sur l'hôte

Garde les VM et les ISO hors du dépôt Git, et les secrets dans un dossier à part :

```powershell
$racine = "C:\SOC-LAB"
"ISO","VM\SOC-WAZUH","VM\WIN-VICTIME","VM\KALI","outils\Sysmon","outils\wazuh-agent","prive" |
  ForEach-Object { New-Item -ItemType Directory -Path "$racine\$_" -Force | Out-Null }
cd $racine
git clone https://github.com/Simon-Sec-Mgmt/soc-homelab.git
```

Puis dans VMware : **Edit → Preferences → Workspace** → `C:\SOC-LAB\VM` comme dossier par défaut.

## Montage pas à pas

Le montage se fait en deux phases réseau : tout s'installe d'abord en **NAT** (Internet), puis les trois VM basculent sur **VMnet2** (isolé) avant le snapshot. L'agent Wazuh s'installe après la bascule, parce qu'il s'enregistre avec l'IP du serveur.

### Phase A — Installation en NAT

**1. Réseau VMnet2** (`docs/01`)

1. VMware → **Edit → Virtual Network Editor → Change Settings → Add Network** → `VMnet2`.
2. Type **Host-only**, décocher **Use local DHCP service**, sous-réseau `10.10.10.0/255.255.255.0`.
3. Laisser **Connect a host virtual adapter** coché, puis protéger l'hôte (PowerShell admin) :

```powershell
Set-NetConnectionProfile -InterfaceAlias "VMware Network Adapter VMnet2" -NetworkCategory Public
```

**2. SOC-WAZUH : Ubuntu Server + Wazuh** (`docs/02`)

1. Installer Ubuntu Server 24.04 en NAT, nom d'hôte `soc-wazuh`, cocher **Install OpenSSH server**.
2. Mettre à jour, puis installer Wazuh tout-en-un :

```bash
sudo apt update && sudo apt full-upgrade -y && sudo reboot
curl -sO https://packages.wazuh.com/4.14/wazuh-install.sh
sudo bash ./wazuh-install.sh -a
```

3. Noter le mot de passe `admin` affiché à la fin dans un gestionnaire de mots de passe, jamais dans Git.
4. À 16 Go : limiter le heap de l'indexeur à 1 Go, puis passer la VM à 4 Go.

```bash
sudo sed -i 's/^-Xms.*/-Xms1g/; s/^-Xmx.*/-Xmx1g/' /etc/wazuh-indexer/jvm.options
sudo systemctl restart wazuh-indexer
```

Reste en Wazuh 4.x : Wazuh 5 change les ports et l'enrôlement des agents.

**3. WIN-VICTIME : Windows 11, audit et Sysmon** (`docs/03`)

1. Installer Windows 11 Entreprise en NAT (4 Go, 2 vCPU), nom `WIN-VICTIME`, compte local `labadmin`.
2. Installer VMware Tools (**VM → Install VMware Tools** → `setup64.exe`), puis les mises à jour Windows.
3. Copier `configs\windows\` du dépôt dans `C:\Tools\scripts\` et lancer en PowerShell admin :

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\01-auditpol-baseline.ps1   # stratégie d'audit avancée, journal Sécurité 512 Mo
.\02-install-sysmon.ps1      # télécharge Sysmon + config SwiftOnSecurity
```

4. Télécharger dès maintenant le MSI de l'agent (même version que le manager), puisqu'il n'y aura plus d'Internet après la bascule :

```powershell
Invoke-WebRequest "https://packages.wazuh.com/4.x/windows/wazuh-agent-4.14.0-1.msi" -OutFile C:\Tools\wazuh-agent.msi
```

**4. Alerte 4719 avec ntfy** (`docs/04`)

1. Installer l'appli ntfy et s'abonner à un sujet long et impossible à deviner (prends le tien, pas le mien).
2. Sur WIN-VICTIME, mettre le sujet dans `C:\SEC_MGMT_SCRIPTS\ntfy-topic.txt` et y copier `03-alerte-4719.ps1`.
3. Créer la tâche planifiée :

```powershell
schtasks /Create /TN "SOC\Alerte-4719" /RU SYSTEM /RL HIGHEST /F `
  /SC ONEVENT /EC Security /MO "*[System[(EventID=4719)]]" `
  /TR "powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\SEC_MGMT_SCRIPTS\03-alerte-4719.ps1"
```

4. Tester tout de suite, pendant que la VM a encore Internet :

```powershell
auditpol /set /subcategory:"{0CCE9215-69AE-11D9-BED3-505054503030}" /failure:disable
auditpol /set /subcategory:"{0CCE9215-69AE-11D9-BED3-505054503030}" /failure:enable
```

Une notification doit arriver sur ton téléphone. Fais-en une capture : après la bascule, ntfy.sh n'est plus joignable.

**5. KALI** (`docs/05`)

1. Décompresser l'image VMware de Kali, ouvrir le `.vmx`, mettre 2 Go de RAM.
2. Changer le mot de passe par défaut et mettre à jour :

```bash
passwd
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y netexec
```

### Phase B — Bascule sur VMnet2

Pour chaque VM : l'éteindre, **VM → Settings → Network Adapter → Custom: VMnet2**, la redémarrer, puis fixer l'IP.

| VM | IP | Commande |
| --- | --- | --- |
| SOC-WAZUH | 10.10.10.10/24 | Copier `configs/ubuntu/50-labo-static.yaml` dans `/etc/netplan/`, adapter l'interface (`ip -br a`), `sudo chmod 600` puis `sudo netplan apply` |
| WIN-VICTIME | 10.10.10.20/24 | `New-NetIPAddress -InterfaceAlias (Get-NetAdapter \| ? Status -eq Up).Name -IPAddress 10.10.10.20 -PrefixLength 24` |
| KALI | 10.10.10.30/24 | `sudo nmcli connection modify "Wired connection 1" ipv4.method manual ipv4.addresses 10.10.10.30/24 ipv4.gateway "" ipv4.dns ""` puis `nmcli connection up` |

Aucune passerelle ni DNS : rien ne peut sortir de 10.10.10.0/24.

**6. Agent Wazuh sur WIN-VICTIME**

SOC-WAZUH doit être allumée depuis 2 à 3 minutes.

```powershell
msiexec.exe /i C:\Tools\wazuh-agent.msi /q WAZUH_MANAGER="10.10.10.10" WAZUH_AGENT_NAME="WIN-VICTIME"
```

Ajouter le bloc de `configs/wazuh/agent-localfile.xml` juste avant `</ossec_config>` dans `C:\Program Files (x86)\ossec-agent\ossec.conf`, puis `NET START WazuhSvc`. Ensuite : baisser WIN-VICTIME à 3 Go et désactiver glisser-déposer et copier-coller (**VM → Settings → Options → Guest Isolation**).

## Validation et snapshots

Ton labo est identique au mien quand toutes les cases ci-dessous sont cochées ; fige alors cet état dans un snapshot `00-baseline` par VM.

- [ ] Les trois VM sont sur VMnet2 uniquement, et `ping 1.1.1.1` échoue depuis Kali
- [ ] `sudo systemctl status wazuh-manager wazuh-indexer wazuh-dashboard` : trois services `active (running)`
- [ ] Le dashboard s'ouvre depuis l'hôte sur `https://10.10.10.10` (certificat auto-signé normal)
- [ ] `Test-NetConnection 10.10.10.10 -Port 1514` depuis WIN-VICTIME renvoie `True`
- [ ] L'agent `WIN-VICTIME` est **Active** dans le dashboard
- [ ] Des événements Sysmon apparaissent dans **Threat Hunting** (`data.win.system.channel: Microsoft-Windows-Sysmon/Operational`)
- [ ] `auditpol /get /category:*` montre les sous-catégories activées
- [ ] La notification ntfy du test 4719 a été reçue pendant la phase NAT

Note aussi les alertes de faible gravité que Wazuh lève déjà sur un poste propre, dans le tableau de `docs/06`. On s'en servira pour distinguer le bruit de fond d'une vraie détection.

| VM | Snapshot | Restaurer après un scénario ? |
| --- | --- | --- |
| SOC-WAZUH | `00-baseline` | Non : on garde l'historique des alertes |
| WIN-VICTIME | `00-baseline` | Oui, après chaque scénario |
| KALI | `00-baseline` | Seulement en cas de problème |

Prends les snapshots VM éteintes : **VM → Snapshot → Take Snapshot**. Ordre de démarrage ensuite : SOC-WAZUH, attendre 2 à 3 minutes, WIN-VICTIME, puis Kali au besoin.

## Collaborer sur le projet

On travaille chacun sur son propre labo, et on partage seulement la documentation, les scripts et les règles de détection par le dépôt Git.

### Scénarios prévus

Chaque scénario part du snapshot `00-baseline` de WIN-VICTIME et se documente dans `scenarios/` : ce qu'on lance, ce que Wazuh voit, ce qu'il rate.

| # | Scénario | Lancé depuis | Événements attendus |
| --- | --- | --- | --- |
| 1 | Force brute SMB (`nxc`) | KALI | 4625, 4776, puis 4624 |
| 2 | Création d'un compte admin local | WIN-VICTIME | 4720, 4732 |
| 3 | Persistance : tâche planifiée + PowerShell | WIN-VICTIME | 4698, 4688, Sysmon 1 |
| 4 | Désactivation de l'audit | WIN-VICTIME | 4719 |

### Règles du dépôt

- **Une branche par contribution** (`scenario/05-xxx`, `docs/correction-yyy`), puis une pull request que l'autre relit.
- **Noms identiques partout** : `SOC-WAZUH`, `WIN-VICTIME`, `KALI` et les IP 10.10.10.10/20/30, dans les docs, les captures et le nom de l'agent. Des noms différents d'une capture à l'autre font douter qu'il s'agit d'un vrai labo.
- **Aucun secret** : mots de passe, sujet ntfy, `wazuh-install-files.tar` restent dans `C:\SOC-LAB\prive\`. Le `.gitignore` les bloque, mais vérifie `git status` avant chaque commit.
- **Pas de fichiers de VM** (`.vmdk`, `.iso`, `.ova`) : trop lourds pour GitHub.
- **Scripts PowerShell en UTF-8 avec BOM**, sinon les accents s'affichent mal.
- **Captures** dans `captures/`, nommées par étape (`07-memoire-hote.png`), sans sujet ntfy ni mot de passe visibles.
- **Mesures réelles uniquement** : on ne remplit les tableaux (bruit de fond, RAM) qu'avec ce qu'on a vraiment observé.

### Règle de sécurité

On n'attaque que WIN-VICTIME, depuis KALI, sur VMnet2. Jamais l'hôte, jamais le réseau de la maison, jamais le labo de l'autre.

## Dépannage

| Symptôme | Cause probable | Correctif |
| --- | --- | --- |
| Agent « Never connected » ou « Disconnected » | Agent installé avec l'IP NAT du serveur, ou SOC-WAZUH pas encore prête | Vérifier `<address>10.10.10.10</address>` dans `ossec.conf`, puis `Restart-Service WazuhSvc` |
| Dashboard très lent ou indexeur qui plante | RAM saturée sur l'hôte | Heap indexeur à 1 Go, éteindre Kali, Kali en mode console (`sudo systemctl isolate multi-user.target`) |
| Aucun événement Sysmon dans Wazuh | Bloc `localfile` absent de `ossec.conf` | Ajouter `configs/wazuh/agent-localfile.xml`, redémarrer l'agent |
| Pas de notification ntfy | VM déjà sur VMnet2, sans Internet | Normal après la bascule ; tester l'alerte en phase NAT |
| Accents illisibles dans les scripts | Fichier enregistré sans BOM | Réenregistrer en UTF-8 avec BOM |
| Glisser-déposer impossible vers la VM | VMware Tools absent ou isolation activée | Installer VMware Tools, cocher **Enable drag and drop** dans **Guest Isolation** |
| Kali joint l'hôte | Adaptateur VMnet2 de l'hôte en profil Privé | Le forcer en Public (étape 1) |
| Version d'agent refusée | Agent plus récent que le manager | Prendre exactement la version du manager (**Agents → Deploy new agent** la donne) |
