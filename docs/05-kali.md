# 05 — VM Kali Linux

**Objectif :** préparer le poste attaquant qui servira aux scénarios de détection.

## Installation

Utiliser l'**image VMware préconstruite** du site officiel de Kali : on décompresse l'archive et on ouvre le fichier `.vmx`. Aucune installation n'est nécessaire.

| Paramètre | Valeur |
| --- | --- |
| vCPU / RAM | 2 / 4 Go |
| Carte réseau | NAT pour les mises à jour, puis VMnet2 |
| Identifiants par défaut | `kali` / `kali`, **à changer au premier démarrage** (`passwd`) |

## Mise à jour

```bash
sudo apt update && sudo apt full-upgrade -y
```

## Passage en IP fixe sur VMnet2

Kali utilise NetworkManager :

```bash
nmcli connection show            # repérer le nom de la connexion filaire
sudo nmcli connection modify "Wired connection 1" \
  ipv4.method manual ipv4.addresses 10.10.10.30/24 ipv4.gateway "" ipv4.dns ""
sudo nmcli connection up "Wired connection 1"
```

## Vérification

- [ ] `ping -c 2 10.10.10.20` répond (si le pare-feu Windows autorise l'ICMP) ou `nmap -Pn -p 3389,445 10.10.10.20` atteint la cible
- [ ] `ping -c 2 1.1.1.1` **échoue** : pas d'accès Internet, l'isolation fonctionne

> Aucune attaque n'est lancée à cette étape. Les scénarios commencent après la validation de l'état de référence.
