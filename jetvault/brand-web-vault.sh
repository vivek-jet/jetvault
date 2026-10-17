#!/bin/sh
# Applies JetVault branding to a prebuilt web vault (the bw_web_builds release used by upstream).
# Used by the Dockerfiles, and can be run by hand on any extracted web vault:
#
#   jetvault/brand-web-vault.sh /path/to/web-vault
#
# Only images are swapped and a few exact product-name strings are replaced, so it keeps
# working across web vault versions. Any string that no longer matches is simply left alone.
set -eu

VAULT_DIR="${1:?usage: brand-web-vault.sh <web-vault-dir>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -f "${VAULT_DIR}/index.html" ]; then
    echo "brand-web-vault: ${VAULT_DIR} does not look like a web vault (no index.html)" >&2
    exit 1
fi

# Logos, icons and favicons
cp -R "${SCRIPT_DIR}/web-vault/." "${VAULT_DIR}/"

# Portable in-place sed (GNU, BSD and busybox)
replace() {
    file="$1"
    shift
    sed -i.jvbak "$@" "${file}" && rm -f "${file}.jvbak"
}

replace "${VAULT_DIR}/index.html" \
    -e 's/Vaultwarden Web/JetVault/g' \
    -e 's/alt="Vaultwarden"/alt="JetVault"/g' \
    -e 's/#175DDC/#4F46E5/g'

for manifest in "${VAULT_DIR}"/*.json; do
    grep -q '"Vaultwarden Web"' "${manifest}" 2>/dev/null || continue
    replace "${manifest}" \
        -e 's/"Vaultwarden Web"/"JetVault"/' \
        -e 's/"theme_color": "#FFFFFF"/"theme_color": "#4F46E5"/'
done

for html in "${VAULT_DIR}"/*-connector.html; do
    [ -f "${html}" ] || continue
    replace "${html}" -e 's/alt="Vaultwarden"/alt="JetVault"/g'
done

# Page title, logo alt text and the issuer shown in authenticator apps for new TOTP setups.
# The "modified version of the Bitwarden Web Vault for Vaultwarden" credits in the About dialog are kept.
for js in "${VAULT_DIR}"/app/main.*.js; do
    [ -f "${js}" ] || continue
    replace "${js}" \
        -e 's/"Vaultwarden Web"/"JetVault"/g' \
        -e 's/"alt","Vaultwarden"/"alt","JetVault"/g' \
        -e 's#otpauth://totp/Vaultwarden:#otpauth://totp/JetVault:#g' \
        -e 's/&issuer=Vaultwarden"/\&issuer=JetVault"/g'
done

# The logos inside the app are inline SVG template literals in the bundles (not image files):
# the header wordmark, the collapsed side-nav icon and the expanded side-nav logos
# ("Password Manager", "Admin Console", ...) which live in lazily loaded chunks too.
for js in "${VAULT_DIR}"/*.js "${VAULT_DIR}"/app/*.js; do
    [ -f "${js}" ] || continue
    grep -q -e '<title>Vaultwarden</title>' -e '-logo-clip)' "${js}" || continue
    JV_LOGO="$(cat "${SCRIPT_DIR}/web-vault-inline/logo.svg")" \
    JV_NAV_ICON="$(cat "${SCRIPT_DIR}/web-vault-inline/nav-icon.svg")" \
    JV_NAV_LOGO="$(cat "${SCRIPT_DIR}/web-vault-inline/nav-logo.svg")" \
    perl -0pi -e '
        sub nav_logo {
            my $subtitle = join " ", map { ucfirst } split /-/, shift;
            (my $svg = $ENV{JV_NAV_LOGO}) =~ s/__SUBTITLE__/$subtitle/g;
            return $svg;
        }
        s{<svg version="1\.1" viewBox="0 0 290 60"[^`]*?<title>Vaultwarden</title>[^`]*?</svg>\s*}{$ENV{JV_LOGO}\n}g;
        s{<svg version="1\.1" viewBox="0 0 60 60"[^`]*?<title>Vaultwarden</title>[^`]*?</svg>\s*}{$ENV{JV_NAV_ICON}\n}g;
        s{<svg version="1\.1" viewBox="0 0 800 200"[^`]*?clip-path="url\(#([a-z-]+)-logo-clip\)"[^`]*?</svg>\s*}{nav_logo($1) . "\n"}ge;
    ' "${js}"
done

echo "brand-web-vault: applied JetVault branding to ${VAULT_DIR}"
