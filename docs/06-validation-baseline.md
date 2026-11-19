# 06 — Validation de l'état de référence et snapshots

**Objectif :** confirmer que tout fonctionne avant la première attaque, puis figer cet état dans des snapshots.

Une détection n'a de valeur que si on sait ce qui est normal. Cette étape établit la référence : quelles alertes Wazuh lève déjà sur un poste propre.

## Liste de contrôle finale

### Réseau

- [ ] Les trois VM sont sur VMnet2 uniquement
- [ ] Aucune VM ne joint Internet (`ping 1.1.1.1` échoue)
- [ ] Le dashboard est accessible depuis le PC hôte : `https://10.10.10.10`

### Wazuh

- [ ] Agent `WIN-VICTIME` à l'état **Active**
- [ ] Événements du journal Sécurité reçus (ex. 4624 à l'ouverture de session)
- [ ] Événements Sysmon reçus (ex. Event ID 1, création de processus)

### Windows

- [ ] Stratégie d'audit appliquée (`auditpol /get /category:*`)
- [ ] Sysmon en cours d'exécution
- [ ] Alerte 4719 testée pendant la phase NAT (voir étape 04)

## Bruit de fond à noter

Sur un poste propre, Wazuh lève déjà des alertes de faible gravité (mises à jour, services, résultats SCA). Les noter ici sert à les distinguer plus tard d'une vraie activité suspecte.

| Règle Wazuh | Niveau | Description | Fréquence observée |
| --- | --- | --- | --- |
| à compléter | | | |

## Snapshots de référence

Éteindre proprement les VM, puis dans VMware : **VM → Snapshot → Take Snapshot**.

| VM | Nom du snapshot | Description |
| --- | --- | --- |
| SOC-WAZUH | `00-baseline` | Wazuh installé, IP fixe, agent enrôlé |
| WIN-VICTIME | `00-baseline` | Audit + Sysmon + agent, IP fixe, aucune attaque |
| KALI | `00-baseline` | À jour, IP fixe |

Après chaque scénario d'attaque, **WIN-VICTIME** revient à `00-baseline`. La VM SOC-WAZUH n'est pas restaurée, pour conserver l'historique des alertes.
