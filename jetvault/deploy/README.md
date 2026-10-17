# Deploying JetVault

One small always-on Linux server running two containers:

- `jetvault`: the JetVault image from `ghcr.io/vivek-jet/jetvault`, built by `.github/workflows/jetvault-image.yml` on every push to `main`
- `caddy`: HTTPS with automatic Let's Encrypt certificates, proxying to JetVault (WebSockets included)

Data (SQLite database, encryption key, attachments) lives in `/opt/jetvault/data`.

## First deploy (AWS Lightsail, Ubuntu 24.04)

1. Create an instance (1 GB RAM is enough), attach a **static IP** and open ports **80** and **443**
   in the instance's networking tab. Turn on **automatic snapshots**.
2. Add a DNS `A` record for your hostname (e.g. `vault.example.com`) pointing at the static IP.
3. Copy this folder to the server and run the bootstrap as root:

   ```sh
   scp -r jetvault/deploy ubuntu@<static-ip>:/tmp/jetvault-deploy
   ssh ubuntu@<static-ip> 'sudo JETVAULT_HOSTNAME=vault.example.com ACME_EMAIL=it@example.com bash /tmp/jetvault-deploy/bootstrap.sh'
   ```

4. Read the admin token once from `/opt/jetvault/admin-token.txt`, save it in a safe place, then delete the file.
5. Open `https://vault.example.com/admin`, invite your users, and configure SMTP in `/opt/jetvault/.env`
   so invites and 2FA emails go out (`docker compose up -d` in `/opt/jetvault` after editing).

Public sign-ups are off. People join by invitation from the admin panel.

## Updating

Push to `main` → the image workflow publishes a new `latest`. Then on the server:

```sh
cd /opt/jetvault && sudo docker compose pull && sudo docker compose up -d
```

## Backups

`backup.sh` runs nightly at 02:17 UTC and keeps 14 archives in `/opt/jetvault/backups`. Each archive holds a
consistent copy of the database plus the encryption key, attachments and sends. Lightsail's automatic
snapshots copy the whole disk, these archives included, off the server.

Restore: stop the stack, extract `db.sqlite3` and `files.tar.gz` from an archive into `/opt/jetvault/data`,
then start the stack again.
