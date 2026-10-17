# JetVault

JetVault is an internal, rebranded build of [Vaultwarden](https://github.com/dani-garcia/vaultwarden).
Only the look and feel changes. Server code, config keys, environment variables and the database
are identical to upstream, so upstream releases merge in cleanly.

## Where the branding lives

| What | Where | Upstream conflict risk |
| --- | --- | --- |
| Logo sources | `jetvault/branding/*.svg` | none (new files) |
| Web vault colors & theme | `src/static/templates/scss/user.vaultwarden.scss.hbs` | none (upstream ships this file as an empty hook) |
| Web vault logos, favicons, title | `jetvault/brand-web-vault.sh`, `jetvault/web-vault/`, `jetvault/web-vault-inline/` | none (new files) |
| Docker build step that runs the script | `docker/Dockerfile.j2` (+ regenerated `Dockerfile.debian` / `Dockerfile.alpine`) | low |
| Admin panel & 404 theme | appended `JetVault theme` block at the end of `src/static/scripts/admin.css` and `404.css` | low |
| Admin/404/email text | `src/static/templates/**/*.hbs` (product name only) | low |
| Admin, favicon & email images | `src/static/images/{vaultwarden-icon,vaultwarden-favicon,logo-gray,404}.png` (same file names) | low |
| Default sender / invite name | `src/config.rs` (`invitation_org_name`, `smtp_from_name` → `JetVault`) | low |

The upstream file names (e.g. `vaultwarden-icon.png`, `.vaultwarden-icon`, `/css/vaultwarden.css`)
are kept on purpose. Renaming them would make every upstream merge conflict.

The About dialog's "modified version of the Bitwarden® Web Vault for Vaultwarden" credit and the
AGPL-3.0 license are kept as-is.

## Changing the logo or colors

1. Edit the SVGs in `jetvault/branding/` (and the inline variants in `jetvault/web-vault-inline/`,
   which use the web vault's theme classes so they follow light/dark mode).
2. Regenerate the PNGs, favicons and overlay files:

   ```sh
   npm install --prefix /tmp/jv-render @resvg/resvg-js@2
   NODE_PATH=/tmp/jv-render/node_modules node jetvault/tools/render-assets.js
   ```

3. Colors: the web vault palette is the `--color-brand-*` / legacy `--color-primary-*` tokens in
   `user.vaultwarden.scss.hbs`; the admin panel palette is the `--jv-*` variables in `admin.css`.

## Pulling in upstream updates

```sh
git remote add upstream https://github.com/dani-garcia/vaultwarden   # once
git fetch upstream
git checkout main
git merge upstream/main          # or: gh repo sync vivek-jet/jetvault
```

If `docker/Dockerfile.j2` conflicts, resolve it, then regenerate the Dockerfiles:

```sh
cd docker && make   # needs python3 with jinja2 + pyyaml
```

After a web vault version bump, rebuild the image and check that `brand-web-vault.sh` still
finds its strings. Anything that no longer matches is simply left unbranded; it never breaks the build.

## Building

```sh
docker build -f docker/Dockerfile.debian -t jetvault:latest .
```

Without Docker, run `jetvault/brand-web-vault.sh /path/to/web-vault` on an extracted
[bw_web_builds](https://github.com/dani-garcia/bw_web_builds/releases) release (needs `perl`).
