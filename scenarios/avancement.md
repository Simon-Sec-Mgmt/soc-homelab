---
tags: [homelab, soc, wazuh, red-vs-blue, portfolio, mitre-attack]
projet: "[[SOC Homelab]]"
date: 2026-11-19
échéance: 2026-11-21
statut: en cours
---

# SOC Homelab — Avancement du projet

## Résumé
Labo SOC personnel (VMware Workstation Pro) avec [[Wazuh]] pour la détection, une cible Windows 11 (`Win11_target`) et une Kali pour l'attaque. L'agent Wazuh tourne seulement sur des VM Windows : je n'attaque jamais mon poste principal. Prochaine étape : relier mon labo à celui d'un ami via [[Lab VPN - Tailscale Red vs Blue|Tailscale]] pour des exercices croisés. Objectif : labo terminé + portfolio GitHub complet **d'ici le samedi 21 novembre 2026**, pour appuyer ma candidature SOC niveau 1.

## Architecture actuelle
```
PC principal (i5-13400F, 16→32 Go)
└─ VMware Workstation Pro
   ├─ Kali Linux            (attaque)
   ├─ Win11_target          (agent Wazuh)
   └─ Manager Wazuh         (dashboard, détection)
```

## Journal d'avancement

### Fait
- [x] VMware Workstation Pro installé
- [x] VM Kali Linux
- [x] VM Windows 11 avec agent Wazuh
- [x] Manager Wazuh fonctionnel
- [x] Choix de conception : aucun agent ni attaque sur la machine hôte
- [x] Conception du VPN inter-labos → [[Lab VPN - Tailscale Red vs Blue]]
- [x] Scénarios Red vs Blue rédigés → [[SOC Homelab - Scenarios Red vs Blue]]

### À faire — Réseau / VPN
- [ ] Créer VMnet2 host-only isolé (`10.10.10.0/24`)
- [ ] Déplacer Win11_target sur VMnet2, repointer l'agent vers `10.10.10.10`
- [ ] Déployer la VM passerelle + Tailscale (`--advertise-routes`, `--snat-subnet-routes=false`)
- [ ] Inviter l'ami, appliquer les ACL, tests d'isolement
- [ ] L'ami monte son côté (`10.20.20.0/24`)

### À faire — Visibilité / détection
- [ ] Installer [[Sysmon]] (config SwiftOnSecurity) + canal dans `ossec.conf`
- [ ] Audit avancé : Process Creation avec ligne de commande, Logon, Account Management
- [ ] PowerShell Script Block Logging (4104)
- [ ] Vérifier la remontée des alertes dans le dashboard

### À faire — Portfolio GitHub
- [ ] README : architecture, schéma réseau, choix de sécurité
- [ ] Un rapport d'incident par round (modèle dans le doc scénarios)
- [ ] Captures du dashboard Wazuh (IP et emails masqués)
- [ ] Règles Wazuh personnalisées écrites pendant les rounds

## Décisions
- 2026-11-19 — Tailscale plutôt que WireGuard brut : pas de port ouvert, ACL centralisées.
- 2026-11-19 — SNAT désactivé sur le subnet router → IP réelle de l'attaquant visible dans Wazuh.
- 2026-11-19 — Cible sans accès internet (pas de masquerade sur la passerelle).

## Liens
- [[Lab VPN - Tailscale Red vs Blue]]
- [[SOC Homelab - Scenarios Red vs Blue]]
- [[Wazuh]] · [[Sysmon]] · [[MITRE ATT&CK]]
