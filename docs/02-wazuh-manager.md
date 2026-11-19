# 02 — Serveur Wazuh sur Ubuntu Server

**Objectif :** installer les trois composants centraux de Wazuh (manager, indexer, dashboard) sur une seule VM Ubuntu Server.

## Création de la VM

| Paramètre | Valeur |
| --- | --- |
| OS | Ubuntu Server 24.04 LTS |
| vCPU / RAM / disque | 4 / 8 Go / 50 Go |
| Carte réseau | NAT pendant l'installation, puis VMnet2 |
| Nom d'hôte | `soc-wazuh` |

Ressources alignées sur la recommandation de Wazuh pour un déploiement *quickstart* de 1 à 25 agents.

Pendant l'installation d'Ubuntu : cocher **Install OpenSSH server**, ne pas installer de snaps supplémentaires.

## Mise à jour du système

```bash
sudo apt update && sudo apt full-upgrade -y
sudo reboot
```

## Installation de Wazuh (tout-en-un)

```bash
curl -sO https://packages.wazuh.com/4.14/wazuh-install.sh
sudo bash ./wazuh-install.sh -a
```

> Vérifier la version courante dans la [documentation Wazuh](https://documentation.wazuh.com/current/quickstart.html) avant l'installation. Ce labo utilise la branche 4.x : les ports et la procédure d'enrôlement changent avec Wazuh 5.

À la fin, l'assistant affiche l'identifiant `admin` et son mot de passe. **Le noter dans un gestionnaire de mots de passe, jamais dans ce dépôt.**

Pour retrouver tous les mots de passe générés :

```bash
sudo tar -O -xvf wazuh-install-files.tar wazuh-install-files/wazuh-passwords.txt
```

## Passage en IP fixe sur VMnet2

1. Éteindre la VM, changer la carte réseau de NAT vers **VMnet2**, redémarrer.
2. Identifier l'interface : `ip -br a` (souvent `ens33`).
3. Copier [`configs/ubuntu/50-labo-static.yaml`](../configs/ubuntu/50-labo-static.yaml) dans `/etc/netplan/`, adapter le nom de l'interface, puis :

```bash
sudo chmod 600 /etc/netplan/50-labo-static.yaml
sudo netplan apply
ip -br a     # doit afficher 10.10.10.10/24
```

## Ports utilisés

| Port | Usage |
| --- | --- |
| 1514/TCP | Réception des journaux des agents |
| 1515/TCP | Enrôlement des agents |
| 443/TCP | Dashboard web |
| 55000/TCP | API Wazuh |

## Vérification

```bash
sudo systemctl status wazuh-manager wazuh-indexer wazuh-dashboard --no-pager
```

- [ ] Les trois services sont `active (running)`
- [ ] Le dashboard s'ouvre depuis le PC hôte : `https://10.10.10.10` (avertissement de certificat auto-signé normal)
- [ ] Connexion avec le compte `admin` réussie
