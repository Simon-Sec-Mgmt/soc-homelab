# 07 — Contrainte matérielle : faire tourner le labo avec 16 Go de RAM

**Objectif :** faire fonctionner un SIEM, un poste Windows surveillé et une machine attaquante sur un seul PC de 16 Go de RAM, sans ralentir le PC hôte au point de le rendre inutilisable.

## Le problème

Avec les réglages par défaut, le labo demande plus de mémoire que le PC n'en possède :

| Composant | RAM par défaut / recommandée |
| --- | --- |
| SOC-WAZUH (Wazuh tout-en-un) | 8 Go recommandés |
| WIN-VICTIME (Windows 11) | 4 Go minimum |
| KALI (avec bureau) | 4 Go |
| PC hôte (Windows + VMware) | ~4 à 6 Go |
| **Total** | **~20 à 22 Go**, pour 16 Go disponibles |

Le goulot d'étranglement principal est l'**indexeur Wazuh** (basé sur OpenSearch, en Java). Par défaut, il réserve la moitié de la RAM de sa VM pour sa mémoire Java (*heap*).

Quand la RAM est saturée, l'hôte bascule sur le fichier d'échange (*swap*). Le dashboard Wazuh devient alors très lent, l'indexeur peut planter et des événements arrivent en retard.

## La solution : un budget mémoire

| VM | RAM allouée | Réglage |
| --- | --- | --- |
| SOC-WAZUH | 4 Go | Minimum officiel de Wazuh ; heap de l'indexeur limité à 1 Go |
| WIN-VICTIME | 3 Go | 4 Go pendant l'installation (exigence de Windows 11), puis réduit à 3 Go |
| KALI | 2 Go | Sans interface graphique pendant les attaques |
| PC hôte | ~7 Go | Applications non essentielles fermées |

### 1. Limiter le heap de l'indexeur Wazuh

Sur SOC-WAZUH :

```bash
sudo sed -i 's/^-Xms.*/-Xms1g/; s/^-Xmx.*/-Xmx1g/' /etc/wazuh-indexer/jvm.options
sudo systemctl restart wazuh-indexer
```

Vérification :

```bash
grep -E '^-Xm[sx]' /etc/wazuh-indexer/jvm.options   # doit afficher -Xms1g et -Xmx1g
free -h
```

> Pour un labo d'un seul agent, 1 Go de heap est suffisant. En production, on suit les recommandations de Wazuh selon le nombre d'agents et le volume d'événements.

### 2. Kali sans bureau pendant les attaques

Les outils utilisés (`nxc`, `hydra`, `nmap`) fonctionnent en ligne de commande. Couper l'interface graphique libère plusieurs centaines de Mo :

```bash
sudo systemctl isolate multi-user.target   # mode console
sudo systemctl isolate graphical.target    # retour au bureau
```

### 3. Deux VM allumées la plupart du temps

Seuls les scénarios lancés depuis le réseau, comme la force brute SMB, ont besoin de Kali. Les scénarios de post-compromission (création de compte, persistance, modification de l'audit) sont simulés directement sur WIN-VICTIME.

| Activité | VM allumées | RAM des VM |
| --- | --- | --- |
| Configuration, scénarios locaux, analyse | SOC-WAZUH + WIN-VICTIME | 7 Go |
| Scénarios réseau depuis Kali | Les trois | 9 Go |

### 4. Réglages VMware Workstation

- **Edit → Preferences → Memory** : *Allow some virtual machine memory to be swapped*
- Les fichiers des VM sont sur un SSD, pas sur un disque dur.

### 5. Ordre de démarrage

1. SOC-WAZUH : attendre 2 à 3 minutes que le dashboard réponde.
2. WIN-VICTIME : l'agent se reconnecte au serveur.
3. KALI : seulement quand un scénario réseau l'exige.

## Mesures

Relevées dans le Gestionnaire des tâches de l'hôte (onglet Performances → Mémoire) et avec `free -h` sur SOC-WAZUH.

| Situation | RAM utilisée sur l'hôte | Dashboard Wazuh |
| --- | --- | --- |
| Réglages par défaut, 3 VM | _à mesurer_ | _à mesurer_ |
| Budget mémoire, 2 VM | _à mesurer_ | _à mesurer_ |
| Budget mémoire, 3 VM | _à mesurer_ | _à mesurer_ |

Capture : `captures/07-memoire-hote.png`

## Limites et compromis

- Avec 1 Go de heap, l'indexeur supporte un seul agent et un faible volume d'événements. Ajouter d'autres agents ou garder un long historique demanderait plus de mémoire.
- Le dashboard reste plus lent qu'avec 8 Go, surtout pour les recherches sur plusieurs jours.
- Les trois VM ne tournent ensemble que pendant les scénarios réseau. Le reste du temps, Kali est éteinte.
- Passer à 32 Go de RAM retirerait cette contrainte et permettrait d'ajouter TheHive au labo.

## Ce que j'en retiens

Avant d'ajouter un outil à un SOC, il faut savoir ce qu'il consomme. Un SIEM mal dimensionné ne fait pas que ralentir : il peut perdre ou retarder des événements, et donc manquer une détection.
