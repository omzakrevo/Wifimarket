# Déploiement automatique de la base (GitHub → serveur Supabase)

À chaque fusion d'une modification de `supabase/migrations/` sur `main`, GitHub applique **uniquement les nouvelles migrations** sur le serveur.
Chaque migration s'exécute dans une transaction : si elle échoue, rien n'est modifié et le déploiement s'arrête (le workflow devient rouge).

## Installation (une seule fois)

### 1. Sur votre PC (PowerShell) : créer une clé réservée au déploiement
```powershell
ssh-keygen -t ed25519 -f deploy_key -N '""' -C "github-deploy"
```
Cela crée `deploy_key` (privée) et `deploy_key.pub` (publique). **Ne partagez jamais la clé privée.**

### 2. Sur le serveur : créer l'utilisateur `deploy` limité à la migration
Connectez-vous (`ssh ubuntu@15.235.100.193`), puis collez **une commande à la fois** :
```bash
sudo adduser --disabled-password --gecos "" deploy
sudo usermod -aG docker deploy
sudo install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
```
Copiez le script sur le serveur (depuis le dépôt `deploy/vps/migrate.sh`) :
```bash
sudo install -m 755 -o root -g root migrate.sh /usr/local/bin/wifimarket-migrate
```
Puis autorisez la clé publique, **limitée à cette seule commande** (remplacez `CLE_PUBLIQUE` par le contenu de `deploy_key.pub`) :
```bash
echo 'command="/usr/local/bin/wifimarket-migrate",no-pty,no-port-forwarding,no-agent-forwarding,no-X11-forwarding CLE_PUBLIQUE' | sudo tee /home/deploy/.ssh/authorized_keys
sudo chown deploy:deploy /home/deploy/.ssh/authorized_keys && sudo chmod 600 /home/deploy/.ssh/authorized_keys
```

### 3. Récupérer l'empreinte du serveur (sur votre PC)
```powershell
ssh-keyscan -t ed25519 15.235.100.193
```
Copiez la ligne affichée.

### 4. Dans GitHub : Settings → Secrets and variables → Actions → New repository secret
| Nom | Valeur |
|---|---|
| `VPS_HOST` | `15.235.100.193` |
| `VPS_SSH_KEY` | tout le contenu du fichier `deploy_key` (clé privée) |
| `VPS_KNOWN_HOSTS` | la ligne obtenue à l'étape 3 |

Ajoutez-les dans l'environnement **production** (Settings → Environments → production → Environment secrets), où vous pouvez aussi exiger une validation manuelle avant chaque déploiement.

### 5. Tester
Onglet **Actions** → « Déploiement base de données » → *Run workflow*.

## Utilisation au quotidien
1. Ajoutez un fichier `supabase/migrations/0012_description.sql` (numéro suivant).
2. Fusionnez sur `main` : le déploiement part tout seul.
3. Pour revenir en arrière, écrivez une **nouvelle** migration qui corrige (ne modifiez jamais une migration déjà appliquée).

Le suivi est dans la table `wm_deploy.schema_migrations` (non exposée par l'API).
