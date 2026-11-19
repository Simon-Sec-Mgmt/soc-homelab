# 04 — Alerte 4719 en temps réel avec ntfy

**Objectif :** recevoir une notification sur mon téléphone dès que la stratégie d'audit de la VM Windows est modifiée.

## Pourquoi l'Event ID 4719

L'événement 4719 signale une modification de la stratégie d'audit. Un attaquant qui a obtenu les droits administrateur désactive souvent l'audit pour ne plus laisser de traces (MITRE ATT&CK T1562.002, *Disable Windows Event Logging*). Être averti immédiatement permet de réagir avant que l'activité suivante passe inaperçue.

Cette alerte complète Wazuh : elle ne dépend pas du serveur SIEM et fonctionne même s'il est arrêté.

## Fonctionnement

```
Event ID 4719 (journal Sécurité)
        │
        ▼
Tâche planifiée Windows (déclencheur « sur un événement »)
        │
        ▼
Script PowerShell 03-alerte-4719.ps1
        │  HTTPS POST
        ▼
ntfy.sh  ──►  appli ntfy sur le téléphone
```

## Prérequis réseau

ntfy.sh est un service Internet : cette alerte demande un accès sortant. Deux options :

- **Option retenue pour la configuration initiale** : tester l'alerte pendant que la VM est encore en NAT, puis la désactiver avant de basculer sur VMnet2.
- **Option avancée (plus tard)** : héberger un serveur ntfy sur la VM SOC-WAZUH pour garder l'alerte active dans le réseau isolé.

## Mise en place

1. Installer l'appli **ntfy** sur le téléphone et s'abonner à un sujet long et difficile à deviner (les sujets publics de ntfy.sh sont lisibles par quiconque connaît leur nom).
2. Sur la VM, créer le dossier des scripts et le fichier du sujet, **hors du dépôt Git** :

```powershell
New-Item -ItemType Directory -Path "C:\SEC_MGMT_SCRIPTS" -Force
Set-Content -Path "C:\SEC_MGMT_SCRIPTS\ntfy-topic.txt" -Value "mon-sujet-secret-a-remplacer"
Copy-Item .\03-alerte-4719.ps1 "C:\SEC_MGMT_SCRIPTS\"
```

3. Créer la tâche planifiée, exécutée en tant que SYSTEM :

```powershell
schtasks /Create /TN "SOC\Alerte-4719" /RU SYSTEM /RL HIGHEST /F `
  /SC ONEVENT /EC Security /MO "*[System[(EventID=4719)]]" `
  /TR "powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\SEC_MGMT_SCRIPTS\03-alerte-4719.ps1"
```

## Test

Provoquer un 4719 volontairement, puis remettre la valeur d'origine :

```powershell
# Désactive puis réactive l'audit des échecs d'ouverture de session
auditpol /set /subcategory:"{0CCE9215-69AE-11D9-BED3-505054503030}" /failure:disable
auditpol /set /subcategory:"{0CCE9215-69AE-11D9-BED3-505054503030}" /failure:enable
```

- [ ] Une notification « Stratégie d'audit modifiée » arrive sur le téléphone
- [ ] L'événement 4719 est aussi visible dans le dashboard Wazuh
