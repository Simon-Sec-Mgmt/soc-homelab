# 01 — Réseau virtuel VMware

**Objectif :** créer un réseau isolé où les trois VM peuvent se parler, sans accès à Internet ni au réseau de la maison.

## Deux phases réseau

| Phase | Carte réseau des VM | Pourquoi |
| --- | --- | --- |
| Installation | NAT | Télécharger les mises à jour, Wazuh, Sysmon |
| Labo (attaques) | VMnet2 uniquement | Isolation : aucun trafic vers Internet ni le réseau local |

Chaque VM est installée en NAT, puis basculée sur VMnet2 avant la prise du snapshot de référence.

## Création de VMnet2

1. VMware Workstation → **Edit → Virtual Network Editor** → *Change Settings* (droits administrateur).
2. **Add Network…** → `VMnet2`.
3. Type : **Host-only**.
4. Décocher **Use local DHCP service** : les IP sont fixes.
5. Sous-réseau : `10.10.10.0`, masque `255.255.255.0`.
6. Laisser coché **Connect a host virtual adapter** : le PC hôte reçoit une adresse sur VMnet2 pour accéder au dashboard Wazuh.

## Plan d'adressage

| Hôte | Adresse | Passerelle | DNS |
| --- | --- | --- | --- |
| PC hôte (adaptateur VMnet2) | 10.10.10.1 | — | — |
| SOC-WAZUH | 10.10.10.10/24 | aucune | aucun |
| WIN-VICTIME | 10.10.10.20/24 | aucune | aucun |
| KALI | 10.10.10.30/24 | aucune | aucun |

Sans passerelle, aucun paquet ne peut sortir du réseau 10.10.10.0/24.

## Protection du PC hôte

L'adaptateur VMnet2 du PC hôte est joignable depuis Kali. Pour respecter la règle « l'hôte n'est jamais une cible » :

```powershell
# Vérifier que Windows classe l'adaptateur VMnet2 en réseau Public (pare-feu le plus strict)
Get-NetConnectionProfile | Where-Object InterfaceAlias -like "*VMnet2*"

# Le forcer en Public si nécessaire
Set-NetConnectionProfile -InterfaceAlias "VMware Network Adapter VMnet2" -NetworkCategory Public
```

En profil Public, le pare-feu Windows bloque les connexions entrantes par défaut.

## Vérification

- [ ] VMnet2 existe, en host-only, sans DHCP
- [ ] L'adaptateur VMnet2 de l'hôte est en profil Public
