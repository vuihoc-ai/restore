#!/usr/bin/env bash
# bootstrap.sh — first (and only) command on a new Mac. Public on purpose: it holds
# no secret, only the order of operations. Everything private comes from GCP after
# `gcloud auth login`, then from the age vault, then from the private repos.
#
#   curl -fsSLo bootstrap.sh https://raw.githubusercontent.com/vuihoc-ai/restore/main/bootstrap.sh
#   shasum -a 256 bootstrap.sh     # compare with SHA256 in the repo README
#   bash bootstrap.sh
#
# Human touches: (1) the sudo password for Homebrew/CLT, (2) the browser login for
# `gcloud auth login`. Nothing else asks unless something is broken.
# Plan + audit: claude-config ~/.claude/plans/2026-09-13-restore-one-touch.md
set -euo pipefail

PROJECT=tako-kb
GCLOUD_ACCOUNT=${GCLOUD_ACCOUNT:-hello@vuihoc.ai}
SECDIR="$HOME/.claude/secrets"
VAULT="$HOME/Documents/KB/me/_secrets/credentials.age"
ok()  { printf '  OK   %s\n' "$*"; }
die() { printf ' ABORT %s\n' "$*" >&2; exit 1; }
step(){ printf '\n== %s ==\n' "$*"; }

step "0. Đây là gì"
printf '  sha256 của script đang chạy: %s\n' "$(shasum -a 256 "$0" | cut -d' ' -f1)"
printf '  so với README của github.com/vuihoc-ai/restore trước khi tiếp (Ctrl-C nếu khác)\n'
sleep 3

# ------------------------------------------------------------------ 1. tools (sudo)
step "1. Xcode CLT + Homebrew + gói nền  [CHẠM 1: mật khẩu sudo]"
if ! xcode-select -p >/dev/null 2>&1; then
  # Headless CLT install: macOS only lists the CLT in softwareupdate while this
  # marker exists. Falls back to the GUI prompt if no label is found.
  touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  label=$(softwareupdate -l 2>/dev/null | grep -o 'Command Line Tools for Xcode-[0-9.]*' | tail -1 || true)
  if [ -n "$label" ]; then
    sudo softwareupdate -i "$label" --verbose >/dev/null && ok "CLT: $label"
  else
    xcode-select --install || true
    die "CLT đang cài qua GUI — chạy lại script khi xong"
  fi
  rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
else
  ok "CLT có"
fi
if [ ! -x /opt/homebrew/bin/brew ]; then
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"
grep -q 'brew shellenv' "$HOME/.zprofile" 2>/dev/null || echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
ok "Homebrew $(brew --version | head -1)"
brew install -q git age node gh jq rclone rustup
brew install -q --cask google-cloud-sdk 2>/dev/null || brew install -q google-cloud-sdk
# The privileged part is over. Drop the sudo timestamp before anything touches a secret.
sudo -k
ok "gói nền xong; sudo đã thu hồi"

# ------------------------------------------------------------------ 2. GCP → identity + vault
step "2. gcloud auth login  [CHẠM 2: đăng nhập Google trong browser]"
GC=$(command -v gcloud || echo /opt/homebrew/share/google-cloud-sdk/bin/gcloud)
if ! "$GC" auth print-access-token --account="$GCLOUD_ACCOUNT" >/dev/null 2>&1; then
  "$GC" auth login "$GCLOUD_ACCOUNT" --brief >/dev/null
fi
"$GC" config set account "$GCLOUD_ACCOUNT" >/dev/null 2>&1 || true
ok "gcloud: $GCLOUD_ACCOUNT"
mkdir -p "$SECDIR" "$(dirname "$VAULT")" && chmod 700 "$SECDIR"
umask 077
if [ ! -s "$SECDIR/age-identity.txt" ]; then
  "$GC" secrets versions access latest --secret=age-identity-vault --project="$PROJECT" > "$SECDIR/age-identity.txt" || die "không lấy được age identity từ GCP"
fi
ok "age identity"
if [ ! -s "$VAULT" ]; then
  "$GC" secrets versions access latest --secret=vault-blob --project="$PROJECT" > "$VAULT" || die "không lấy được vault-blob từ GCP"
fi
ok "vault blob (bản GCP; kb-me clone sau sẽ là bản chính)"
umask 022

# ------------------------------------------------------------------ 3. vault → gh → ~/.claude
step "3. gh đăng nhập từ vault → clone ~/.claude"
vault() { age -d -i "$SECDIR/age-identity.txt" "$VAULT" | sed -n "s/^$1=//p" | head -1; }
tok=$(vault gh.token_vuihoc_ai); [ -n "$tok" ] || die "vault không có gh.token_vuihoc_ai"
printf '%s' "$tok" | gh auth login --with-token -h github.com >/dev/null 2>&1 || die "gh login FAIL (token hết hạn?)"
unset tok
gh auth setup-git >/dev/null 2>&1 || true
ok "gh: $(gh api user -q .login)"
if [ ! -d "$HOME/.claude/.git" ]; then
  keep=$(mktemp -d); cp -a "$SECDIR/." "$keep/"
  [ -d "$HOME/.claude" ] && mv "$HOME/.claude" "$HOME/.claude.pre-restore.$(date +%s)"
  git clone -q "https://github.com/vuihoc-ai/claude-config.git" "$HOME/.claude" || die "clone claude-config FAIL"
  mkdir -p "$SECDIR" && cp -a "$keep/." "$SECDIR/" && rm -rf "$keep"
fi
chmod 700 "$SECDIR"; chmod 600 "$SECDIR/age-identity.txt"
[ -s "$SECDIR/recipients.txt" ] || age-keygen -y "$SECDIR/age-identity.txt" > "$SECDIR/recipients.txt"
ok "~/.claude = claude-config @ $(git -C "$HOME/.claude" rev-parse --short HEAD)"

# ------------------------------------------------------------------ 4. hand over
step "4. restore-all.sh (trong claude-config) — từ đây không cần người nữa"
exec bash "$HOME/.claude/restore/restore-all.sh"
