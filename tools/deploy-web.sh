#!/usr/bin/env bash
## Deploy the Pigeon Simulator web build to the basement box (games.matthews.mx).
##
## Usage:
##   tools/deploy-web.sh              # build → upload → publish → verify
##   tools/deploy-web.sh --first      # ALSO apply the NixOS Caddy vhost first
##                                    # (one-time, drift-guarded — see below)
##   SKIP_BUILD=1 tools/deploy-web.sh # redeploy the existing build/web
##
## Credentials live in the untracked .env.deploy at the repo root (never commit
## it): DEPLOY_HOST, DEPLOY_USER, DEPLOY_PASSWORD (the sudo credential for the
## root steps), DEPLOY_SSH_KEY (login key; recommended — without it ssh will
## prompt once per connection). One-time key setup on a new machine:
##   ssh-keygen -t ed25519 -N '' -f ~/.ssh/pigeon_deploy -C 'pigeon-sim deploy'
##   ssh-copy-id -i ~/.ssh/pigeon_deploy "$DEPLOY_USER@$DEPLOY_HOST"
##
## The --first leg applies the Caddy vhost that the NixOS config already
## defines in the source-of-truth working copy ($NIXOS_SRC): it aborts unless
## the /etc copy differs from the source by EXACTLY the games vhost block
## (additions-only, line-for-line), then copies and runs `nixos-rebuild switch`.
## Per-deploy publishes never touch the NixOS config — Caddy's file_server
## serves /srv/games as-is. Convention: one sibling directory per game under
## /srv/games; this script only ever writes its own.
##
## See VERIFICATION.md → "Web export" and docs/tickets/T-118-web-safari-build.md.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${DEPLOY_ENV_FILE:-$REPO_ROOT/.env.deploy}"
if [ ! -f "$ENV_FILE" ]; then
	echo "ERROR: $ENV_FILE not found — deploy credentials live there (untracked by design)." >&2
	exit 1
fi
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

: "${DEPLOY_HOST:?set DEPLOY_HOST in .env.deploy}"
: "${DEPLOY_USER:?set DEPLOY_USER in .env.deploy}"

DEPLOY_PATH="${DEPLOY_PATH:-/srv/games/pigeon-simulator}"
DEPLOY_DOMAIN="${DEPLOY_DOMAIN:-games.matthews.mx}"
DEPLOY_DNS_REF="${DEPLOY_DNS_REF:-jellyfin.matthews.mx}"
PUBLIC_URL="${PUBLIC_URL:-https://$DEPLOY_DOMAIN/pigeon-simulator}"
NIXOS_SRC="${NIXOS_SRC:-/home/sean/media-stack/media-stack.nix}"
NIXOS_ETC="${NIXOS_ETC:-/etc/nixos/media-stack.nix}"
GODOT_BIN="${GODOT_BIN:-$HOME/bin/Godot_v4.7.2-stable_win64_console.exe}"

SSH_TARGET="$DEPLOY_USER@$DEPLOY_HOST"
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new)
if [ -n "${DEPLOY_SSH_KEY:-}" ]; then
	SSH_OPTS+=(-i "${DEPLOY_SSH_KEY/#\~/$HOME}")
fi

WORK="$(mktemp -d)"
REMOTE_TAG="pigeon-deploy.$$"
trap 'rm -rf "$WORK"' EXIT

log() { printf '[deploy] %s\n' "$*" >&2; }
fail() {
	printf '[deploy] FAIL: %s\n' "$*" >&2
	exit 1
}

# Upload a local shell fragment and run it on the box as root. Root comes from
# sudo fed DEPLOY_PASSWORD on stdin (sudo -S); a root login skips sudo, an
# empty password requires passwordless sudo.
run_root() {
	local frag remote
	frag="$1"
	remote="/tmp/$REMOTE_TAG-$(basename "$frag")"
	scp -q "${SSH_OPTS[@]}" "$frag" "$SSH_TARGET:$remote"
	if [ "$DEPLOY_USER" = "root" ]; then
		ssh "${SSH_OPTS[@]}" "$SSH_TARGET" "bash '$remote'"
	elif [ -n "${DEPLOY_PASSWORD:-}" ]; then
		printf '%s\n' "$DEPLOY_PASSWORD" \
			| ssh "${SSH_OPTS[@]}" "$SSH_TARGET" "sudo -S -p '' bash '$remote'"
	else
		ssh "${SSH_OPTS[@]}" "$SSH_TARGET" "sudo -n bash '$remote'" \
			|| fail "no DEPLOY_PASSWORD and no passwordless sudo — set DEPLOY_PASSWORD in .env.deploy"
	fi
	ssh "${SSH_OPTS[@]}" "$SSH_TARGET" "rm -f '$remote'"
}

# --- preflight: DNS must resolve and match the reference vhost's IP, or Caddy
# cannot obtain its certificate (handoff precondition). ----------------------
dns_addrs() {
	local name="$1"
	if command -v dig >/dev/null 2>&1; then
		dig +short "$name" A | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' | sort -u
	else
		nslookup "$name" 2>/dev/null | sed -n '/^Name:/,$p' \
			| grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -u
	fi
}

check_dns() {
	log "DNS: resolving $DEPLOY_DOMAIN (reference $DEPLOY_DNS_REF)"
	local games ref
	games="$(dns_addrs "$DEPLOY_DOMAIN" || true)"
	ref="$(dns_addrs "$DEPLOY_DNS_REF" || true)"
	if [ -z "$games" ]; then
		[ "${DEPLOY_ALLOW_NO_DNS:-0}" = "1" ] \
			&& log "WARNING: $DEPLOY_DOMAIN does not resolve — staging anyway (DEPLOY_ALLOW_NO_DNS=1); Caddy will retry its certificate until DNS is live." \
			|| fail "DNS: $DEPLOY_DOMAIN does not resolve — add the A record first; Caddy cannot get its certificate without it."
	elif [ -z "$ref" ]; then
		fail "DNS: reference $DEPLOY_DNS_REF does not resolve — cannot compare public IPs."
	elif [ "$games" != "$ref" ] && [ "${DEPLOY_ALLOW_NO_DNS:-0}" != "1" ]; then
		fail "DNS: $DEPLOY_DOMAIN → [${games//$'\n'/ }] but $DEPLOY_DNS_REF → [${ref//$'\n'/ }] — point both names at the same public IP."
	fi
	[ -n "$games" ] && log "DNS OK: ${games//$'\n'/ }" || log "DNS: no record — deploying ahead of DNS by explicit override"
}

# --- build: headless Godot export (the exporter refuses to create build/web). ---
build_web() {
	mkdir -p build/web
	[ -x "$GODOT_BIN" ] || fail "Godot binary not executable: $GODOT_BIN (override with GODOT_BIN=...)"
	log "Exporting web build (Godot headless, ~40 s)"
	if ! "$GODOT_BIN" --headless --path "$REPO_ROOT" --export-release "Web" \
		build/web/index.html >"$WORK/export.log" 2>&1; then
		tail -20 "$WORK/export.log" >&2
		fail "web export failed — full log at $WORK/export.log"
	fi
	local f
	for f in index.html index.js index.wasm index.pck; do
		[ -f "build/web/$f" ] || fail "export output missing build/web/$f"
	done
	if grep -q SharedArrayBuffer build/web/index.wasm 2>/dev/null; then
		fail "index.wasm references SharedArrayBuffer — export preset thread support must stay OFF (iOS Safari)"
	fi
	log "Build OK: $(du -sh build/web | cut -f1)"
}

# --- upload: tar pipe into a sean-owned staging dir (no sudo on this leg). ---
upload() {
	local staging="/tmp/$REMOTE_TAG-staging"
	log "Uploading build to staging $staging"
	ssh "${SSH_OPTS[@]}" "$SSH_TARGET" "rm -rf '$staging' && mkdir -p '$staging'"
	tar -C build/web --exclude='*.import' -cf - . \
		| ssh "${SSH_OPTS[@]}" "$SSH_TARGET" "tar -xf - -C '$staging'"
	printf '%s' "$staging"
}

# --- publish: the handoff's rsync into /srv/games/pigeon-simulator. ---------
publish() {
	local staging="$1"
	log "Publishing to $DEPLOY_PATH"
	cat >"$WORK/publish.sh" <<EOF
set -eu
mkdir -p '$DEPLOY_PATH'
rsync -a --delete --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r '$staging/' '$DEPLOY_PATH/'
# backstop: the world must traverse dirs and read files (caddy user), whatever
# the rsync version does with --chmod on unchanged files
find '$DEPLOY_PATH' -type d -exec chmod 755 {} +
find '$DEPLOY_PATH' -type f -exec chmod 644 {} +
rm -rf '$staging'
test -f '$DEPLOY_PATH/index.html' || { echo 'index.html missing after publish'; exit 4; }
echo PUBLISHED
EOF
	run_root "$WORK/publish.sh"
}

# --- one-time: apply the NixOS config (drift-guarded per the handoff). ------
apply_nixos() {
	log "Applying NixOS config (drift guard: diff must be exactly the games vhost block)"
	cat >"$WORK/apply-nixos.sh" <<EOF
set -eu
src='$NIXOS_SRC'
etc='$NIXOS_ETC'
[ -f "\$src" ] || { echo "ABORT: source-of-truth \$src missing"; exit 3; }
if diff -q "\$etc" "\$src" >/dev/null 2>&1; then
	if grep -q 'virtualHosts\."games\.' "\$etc"; then
		echo ALREADY_APPLIED
		exit 0
	fi
	echo "ABORT: \$etc and \$src are identical but neither contains the games vhost"
	exit 3
fi
d="\$(diff "\$etc" "\$src" || true)"
if printf '%s\n' "\$d" | grep -q '^<'; then
	echo "ABORT: /etc copy differs by deletions/changes, not just the games vhost addition — human review needed. Diff:"
	printf '%s\n' "\$d"
	exit 3
fi
ln="\$(grep -n 'virtualHosts\."games\.' "\$src" | head -1 | cut -d: -f1)"
[ -n "\$ln" ] || { echo "ABORT: no games vhost in \$src"; exit 3; }
indent="\$(sed -n "\${ln}p" "\$src" | sed 's/[^ ].*//')"
start="\$ln"
while [ "\$start" -gt 1 ] && sed -n "\$((start-1))p" "\$src" | grep -q '^[[:space:]]*#'; do start=\$((start-1)); done
end="\$ln"
total="\$(wc -l < "\$src")"
while [ "\$end" -lt "\$total" ] && [ "\$(sed -n "\$((end+1))p" "\$src")" != "\${indent}};" ]; do end=\$((end+1)); done
end=\$((end+1))
sed -n "\${start},\${end}p" "\$src" | sed 's/[[:space:]]*$//' > /tmp/expected.txt
printf '%s\n' "\$d" | grep '^>' | sed 's/^> \?//; s/[[:space:]]*$//' > /tmp/added.txt
if ! diff -u /tmp/expected.txt /tmp/added.txt; then
	echo "ABORT: the /etc-vs-source diff is not exactly the games vhost block — human review needed."
	exit 3
fi
cp "\$src" "\$etc"
nixos-rebuild switch
echo NIXOS_APPLIED
EOF
	run_root "$WORK/apply-nixos.sh"
}

# --- verify: the handoff's curl pair, with a first-deploy cert grace. -------
verify() {
	log "Verifying $PUBLIC_URL/"
	local head try attempts="${VERIFY_ATTEMPTS:-5}"
	for try in $(seq 1 "$attempts"); do
		head="$(curl -fsSI --max-time 20 "$PUBLIC_URL/" 2>/dev/null | head -1 | tr -d '\r' || true)"
		if printf '%s' "$head" | grep -qE 'HTTP/.* 200'; then
			if curl -fsS --max-time 20 "$PUBLIC_URL/" 2>/dev/null | grep -qi '<html'; then
				log "VERIFY OK: $head, HTML body served"
				return 0
			fi
			fail "HTTP 200 but the body is not the game shell (no <html>)"
		fi
		if [ "$try" -eq 1 ]; then
			log "not 200 yet (${head:-no response}) — nudging caddy (first-ever cert issuance can lag)"
			printf 'systemctl reload caddy || systemctl restart caddy\necho RELOADED\n' >"$WORK/reload.sh"
			run_root "$WORK/reload.sh" || true
		fi
		sleep 8
	done
	fail "verify failed (${head:-no response}). First deploy? Check DNS, then journalctl -u caddy -n 50 on the box (sudo). ACME retries automatically once DNS is live."
}

# --- main --------------------------------------------------------------------
FIRST=0
[ "${1:-}" = "--first" ] && FIRST=1

for t in ssh scp tar curl; do
	command -v "$t" >/dev/null 2>&1 || fail "missing local tool: $t"
done

check_dns

if [ "${SKIP_BUILD:-0}" = "1" ] && [ -f build/web/index.html ]; then
	log "SKIP_BUILD=1 — reusing the existing build/web"
else
	build_web
fi

publish "$(upload)"

if [ "$FIRST" = "1" ]; then
	apply_nixos
fi

verify
log "DONE — $PUBLIC_URL is live"
