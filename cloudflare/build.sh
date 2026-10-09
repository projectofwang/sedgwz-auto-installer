#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

rm -rf cloudflare/public
mkdir -p cloudflare/public

cp installer.ps1 cloudflare/public/installer.ps1
cp approved-releases.json cloudflare/public/approved-releases.json
cp cloudflare/landing.html cloudflare/public/index.html
cp cloudflare/favicon.svg cloudflare/public/favicon.svg
mkdir -p cloudflare/public/mascots
for m in fox-ink cat hedgehog otter sloth; do
  cp "cloudflare/mascots/$m-directions.webp" "cloudflare/public/mascots/$m-directions.webp"
  cp "cloudflare/mascots/$m-reactions.webp" "cloudflare/public/mascots/$m-reactions.webp"
done

# Deterministic line endings: checkouts differ by platform (CRLF on Windows,
# LF elsewhere) and both installer.ps1 and approved-releases.json are hashed
# into version.json/SHA256SUMS. Normalize the staged copies to CRLF so the
# Cloudflare origin always matches the GitHub Release origin.
node -e "for (const f of ['cloudflare/public/installer.ps1','cloudflare/public/approved-releases.json']) { const fs = require('fs'); const t = fs.readFileSync(f,'utf8').replace(/\r\n/g,'\n').replace(/\n/g,'\r\n'); fs.writeFileSync(f,t); }"

# Static headers: assets-only deploy, so no-store/security headers must
# come from a _headers file instead of a Worker.
cat > cloudflare/public/_headers <<'HEADERS_EOF'
/*
  X-Content-Type-Options: nosniff
  Referrer-Policy: no-referrer
  X-Frame-Options: DENY
  Strict-Transport-Security: max-age=31536000; includeSubDomains
  Content-Security-Policy: default-src 'self'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'; img-src 'self'; object-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'
/index.html
  Cache-Control: no-store
/
  Cache-Control: no-store
/installer.ps1
  Cache-Control: no-store
  Content-Type: text/plain; charset=utf-8
/version.json
  Cache-Control: no-store
/approved-releases.json
  Cache-Control: no-store
/SHA256SUMS
  Cache-Control: no-store
  Content-Type: text/plain; charset=utf-8
HEADERS_EOF

installer_version="$(sed -n "s/^\$script:InstallerVersion = '\([^']*\)'.*/\1/p" installer.ps1 | head -n1)"
# Parse JSON with node (always present where wrangler runs); a naive
# first-"version"-match would catch the NSSM version instead.
manifest_version="$(node -p "require('./approved-releases.json').installer.version")"

if [[ -z "$installer_version" || -z "$manifest_version" ]]; then
  echo "ERROR: could not determine installer/manifest version." >&2
  exit 1
fi

if [[ "$installer_version" != "$manifest_version" ]]; then
  echo "ERROR: version mismatch: installer.ps1=$installer_version manifest=$manifest_version" >&2
  exit 1
fi

commit="$(git rev-parse HEAD 2>/dev/null || printf 'unknown')"
sha256="$(sha256sum cloudflare/public/installer.ps1 | awk '{print $1}')"
built="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

printf '{"version":"%s","commit":"%s","sha256":"%s","built":"%s"}\n'   "$installer_version" "$commit" "$sha256" "$built" > cloudflare/public/version.json

# Cross-origin check file: compare Cloudflare vs GitHub.
{
  echo "# SHA256SUMS for v$installer_version ($commit)"
  echo "$sha256  installer.ps1"
  sha256sum cloudflare/public/approved-releases.json | awk '{print $1 "  approved-releases.json"}'
} > cloudflare/public/SHA256SUMS

echo "Built Cloudflare assets:"
echo "  version: $installer_version"
echo "  commit:  $commit"
echo "  sha256:  $sha256"
