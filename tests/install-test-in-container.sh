#!/bin/bash
# Exercises install/install.sh, verify.sh and rollback.sh on a fresh ubuntu:20.04 container
# with stock php7.4 under Apache mod_php. Containers have no systemd, so a minimal
# `systemctl` stand-in drives apachectl. Started with --init by tests/install-test.sh.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8
. /src/build/release.env
NEW="${BASE_VERSION}+${SUFFIX}"

printf '%s\n' \
  'deb http://archive.ubuntu.com/ubuntu focal main restricted universe multiverse' \
  'deb http://archive.ubuntu.com/ubuntu focal-updates main restricted universe multiverse' \
  'deb http://security.ubuntu.com/ubuntu focal-security main restricted universe multiverse' \
  > /etc/apt/sources.list
rm -f /usr/sbin/policy-rc.d          # the ubuntu image ships one; install.sh must create its own
apt-get update -qq
apt-get install -y -qq --no-install-recommends apache2 curl ca-certificates \
  libapache2-mod-php7.4="$BASE_VERSION" php7.4-cli="$BASE_VERSION" php7.4-common="$BASE_VERSION" \
  php7.4-json="$BASE_VERSION" php7.4-opcache="$BASE_VERSION" php7.4-readline="$BASE_VERSION" \
  php7.4-mbstring="$BASE_VERSION" php7.4-xml="$BASE_VERSION" php7.4-curl="$BASE_VERSION" >/dev/null
a2dismod -q mpm_event >/dev/null 2>&1 || true; a2enmod -q mpm_prefork php7.4 >/dev/null

cat > /usr/local/bin/systemctl <<'SH'
#!/bin/bash
# minimal stand-in: only what install.sh / rollback.sh call, only for apache2
[ "${1:-}" = is-active ] && shift && [ "${1:-}" = --quiet ] && shift
case "${1:-}:${2:-}" in
  apache2:*|is-active:apache2) pgrep -x apache2 >/dev/null ;;
  start:apache2) apachectl start 2>/dev/null ;;
  *) exit 3 ;;
esac
SH
chmod +x /usr/local/bin/systemctl
apachectl start 2>/dev/null; sleep 2

cp -r /src/install /tmp/rel && cp /debs/*.deb /debs/SHA256SUMS /tmp/rel/
cd /tmp/rel
echo "== install"; ./install.sh /tmp/rel
echo "== verify";  out=$(./verify.sh); echo "$out"
echo "$out" | grep -q "php7.4-common=${NEW} " && echo "$out" | grep -q 'mod_php=current' || { echo "FAIL: not running $NEW"; exit 1; }
[ "$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1/)" = 200 ] || { echo "FAIL: http after install"; exit 1; }
[ ! -e /usr/sbin/policy-rc.d ] || { echo "FAIL: policy-rc.d left behind"; exit 1; }
echo "== install again (must refuse)"; ./install.sh /tmp/rel && { echo "FAIL: second install did not refuse"; exit 1; } || true
echo "== rollback"; ./rollback.sh "/var/backups/php74-rollback-${BASE_VERSION}"
out=$(./verify.sh); echo "$out"
echo "$out" | grep -q "php7.4-common=${BASE_VERSION} " && echo "$out" | grep -q 'mod_php=current' || { echo "FAIL: rollback"; exit 1; }
echo "PASS"
