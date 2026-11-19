# SOC Homelab — Wazuh, Sysmon et alertes en temps réel

Laboratoire personnel qui reproduit l'environnement de travail d'un analyste SOC de niveau 1 : collecte des journaux Windows dans un SIEM, détection d'événements critiques et alertes envoyées sur mobile.

Ce dépôt documente la **configuration initiale** du labo, c'est-à-dire l'état propre de référence avant tout scénario d'attaque. Les scénarios d'attaque et de détection seront documentés séparément dans `scenarios/`.

> Projet réalisé dans le cadre de ma préparation à la certification **Microsoft SC-200** (Security Operations Analyst).

## Architecture

```
                  ┌──────────────────────────────────────────────┐
                  │  PC hôte (Windows) — VMware Workstation Pro  │
                  │  Jamais attaqué : il héberge seulement les VM │
                  └──────────────────────┬───────────────────────┘
                                         │ VMnet2 (host-only, sans NAT)
                                         │ 10.10.10.0/24
        ┌────────────────────────────────┼────────────────────────────────┐
        │                                │                                │
┌───────┴────────┐             ┌─────────┴─────────┐            ┌─────────┴────────┐
│  SOC-WAZUH     │             │  WIN-VICTIME      │            │  KALI            │
│  Ubuntu Server │◄── 1514 ────│  Windows (éval.)  │◄───────────│  Kali Linux      │
│  Wazuh manager │◄── 1515 ────│  Agent Wazuh      │  attaques  │  Attaquant       │
│  + indexer     │             │  Sysmon           │            │                  │
│  + dashboard   │             │  Audit avancé     │            │                  │
│  10.10.10.10   │             │  10.10.10.20      │            │  10.10.10.30     │
└───────┬────────┘             └─────────┬─────────┘            └──────────────────┘
        │ 443 (dashboard)                │ HTTPS (ntfy, phase alerte)
        ▼                                ▼
   Navigateur du PC hôte           Téléphone (appli ntfy)
```

| VM | Rôle | OS | vCPU | RAM | Disque | IP |
| --- | --- | --- | --- | --- | --- | --- |
| SOC-WAZUH | SIEM (manager, indexer, dashboard) | Ubuntu Server 24.04 LTS | 4 | 8 Go | 50 Go | 10.10.10.10 |
| WIN-VICTIME | Poste surveillé | Windows 11 Entreprise (évaluation) | 2 | 4 Go | 60 Go | 10.10.10.20 |
| KALI | Poste attaquant | Kali Linux (image VMware) | 2 | 4 Go | 80 Go | 10.10.10.30 |

## Principes de conception

- **Isolation** : les VM communiquent entre elles sur un réseau virtuel sans accès Internet. Le PC hôte n'est jamais une cible.
- **État de référence** : chaque VM a un instantané (snapshot) « propre » pris à la fin de cette configuration. On y revient après chaque scénario.
- **Visibilité d'abord** : la journalisation Windows est durcie (audit avancé + Sysmon) avant toute attaque, pour que les détections aient des données à analyser.
- **Aucun secret dans le dépôt** : mots de passe, sujet ntfy et clés restent hors de Git (voir `.gitignore`).

## Étapes de la configuration initiale

| # | Étape | Document |
| --- | --- | --- |
| 1 | Réseau virtuel VMware | [docs/01-reseau-vmware.md](docs/01-reseau-vmware.md) |
| 2 | Serveur Wazuh sur Ubuntu Server | [docs/02-wazuh-manager.md](docs/02-wazuh-manager.md) |
| 3 | VM Windows : audit, Sysmon, agent Wazuh | [docs/03-windows-victime.md](docs/03-windows-victime.md) |
| 4 | Alerte 4719 en temps réel avec ntfy | [docs/04-alerte-4719-ntfy.md](docs/04-alerte-4719-ntfy.md) |
| 5 | VM Kali | [docs/05-kali.md](docs/05-kali.md) |
| 6 | Validation de l'état de référence et snapshots | [docs/06-validation-baseline.md](docs/06-validation-baseline.md) |
| 7 | Contrainte matérielle : labo sur 16 Go de RAM | [docs/07-contrainte-16go-ram.md](docs/07-contrainte-16go-ram.md) |
| 8 | Angle mort Sysmon : détection des accès à LSASS (T1003.001) | [docs/08-detection-lsass.md](docs/08-detection-lsass.md) |


## Contenu du dépôt

```
soc-homelab/
├── README.md
├── docs/                         Procédures pas à pas
├── configs/
│   ├── ubuntu/50-labo-static.yaml       IP fixe du serveur Wazuh (netplan)
│   ├── wazuh/agent-localfile.xml        Ajout des journaux Sysmon à l'agent
│   └── windows/
│       ├── 01-auditpol-baseline.ps1     Stratégie d'audit avancée
│       ├── 02-install-sysmon.ps1        Installation de Sysmon
│       └── 03-alerte-4719.ps1           Notification ntfy sur Event ID 4719
└── scenarios/                    (à venir) attaques et détections
```

## Outils

Wazuh 4.14 · Sysmon (Sysinternals) · ntfy · VMware Workstation Pro · Ubuntu Server · Windows 11 Entreprise (évaluation) · Kali Linux

## Prochaines étapes

- [ ] Scénarios d'attaque depuis Kali et analyse des détections dans Wazuh
- [ ] Gestion des cas dans TheHive
- [ ] Laboratoire Microsoft Sentinel et Defender XDR (Azure)
