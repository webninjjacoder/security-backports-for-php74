#!/bin/bash
# Installs the patched php7.4 packages from a release folder and restarts the PHP web
# tier so the new code is actually running. Stops before changing anything if a check fails.
#
#   sudo ./install.sh /path/to/release-folder      (the folder with the .deb files + SHA256SUMS)
#
# Supported: Ubuntu 20.04 (focal) amd64 with Ubuntu's own php7.4 (7.4.3-4ubuntu2.x),
# served by Apache mod_php and/or PHP-FPM.
set -euo pipefail
export LC_ALL=C DEBIAN_FRONTEND=noninteractive
. "$(dirname "$0")/lib.sh"

DEB_DIR=$(cd "${1:?usage: install.sh /path/to/release-folder}" && pwd)
[ "$(id -u)" = 0 ] || die "run as root"

# ---- pre-checks (read-only) ----------------------------------------------------------
. /etc/os-release
[ "${VERSION_CODENAME:-}" = focal ] || die "this release is for Ubuntu 20.04 (focal); this is ${PRETTY_NAME:-unknown}"
[ "$(dpkg --print-architecture)" = amd64 ] || die "this release is for amd64"
CUR=$(dpkg-query -W -f='${Version}' php7.4-common 2>/dev/null) || die "php7.4-common is not installed"
case "$CUR" in
  *deb.sury.org*) die "php7.4 here comes from the ondrej/php PPA ($CUR); these packages are built from Ubuntu's php7.4 and must not replace it" ;;
  7.4.3-4ubuntu2.*) ;;
  *) die "unexpected php7.4 version $CUR" ;;
esac
(cd "$DEB_DIR" && sha256sum -c --quiet SHA256SUMS) || die "checksum mismatch in $DEB_DIR"
NEW=$(ls "$DEB_DIR"/php7.4-common_*_amd64.deb | head -1 | sed -E 's#.*/php7.4-common_([^_]+)_amd64.deb#\1#')
[ "$CUR" != "$NEW" ] || die "already at $NEW"
dpkg --compare-versions "$NEW" gt "$CUR" || die "$NEW is not newer than installed $CUR"

# the binary packages from the php7.4 source package that are installed here
mapfile -t PKGS < <(dpkg-query -W -f='${Package} ${Status}\n' \
  | awk '$NF=="installed" && $(NF-1)=="ok" {print $1}' \
  | grep -E '^(php7\.4(-[a-z0-9]+)?|libapache2-mod-php7\.4|libphp7\.4-embed)$' | sort)
DEBS=()
for p in "${PKGS[@]}"; do
  f=$(ls "$DEB_DIR/${p}_${NEW}_"*.deb 2>/dev/null | head -1 || true)
  [ -n "$f" ] || die "no $NEW package for installed package $p"
  DEBS+=("$f")
done

MODPHP=no; FPM=no
uses_modphp && MODPHP=yes
uses_fpm && FPM=yes
if [ "$MODPHP" = yes ]; then
  apache2ctl configtest 2>&1 | grep -q 'Syntax OK' || die "apache config test fails before any change"
fi
MODS_BEFORE=$(php -m | sort | tr '\n' ' ')
log "installed: $CUR -> installing: $NEW (${#DEBS[@]} packages); mod_php=$MODPHP php-fpm=$FPM"

# ---- keep a way back ------------------------------------------------------------------
BACKUP="/var/backups/php74-rollback-$CUR"
mkdir -p "$BACKUP"
( cd "$BACKUP"
  # Ubuntu's archive keeps only the newest build, so a server still on an older
  # 7.4.3-4ubuntu2.x rolls back to Ubuntu's 7.4.3-4ubuntu2.29 instead.
  for p in "${PKGS[@]}"; do
    ls "${p}_"*.deb >/dev/null 2>&1 && continue
    v=$(dpkg-query -W -f='${Version}' "$p")
    apt-get download -q "$p=$v" >/dev/null 2>&1 \
      || apt-get download -q "$p=7.4.3-4ubuntu2.29" >/dev/null 2>&1 \
      || die "cannot save a rollback copy of $p"
  done )
log "rollback copies: $BACKUP ($(ls "$BACKUP" | wc -l) packages)"

# ---- install only these packages, with service restarts blocked ------------------------
# dpkg -i rather than apt-get: apt would also try to configure unrelated half-configured
# packages (common on images cloned from older disks) and can fail half-way.
block_service_restarts
dpkg -i --force-confold "${DEBS[@]}" > /var/log/php74-backport-install.log 2>&1 \
  || { tail -20 /var/log/php74-backport-install.log; die "dpkg -i failed (web tier NOT restarted); see /var/log/php74-backport-install.log"; }
allow_service_restarts

# ---- verify before restarting -----------------------------------------------------------
for p in "${PKGS[@]}"; do
  [ "$(dpkg-query -W -f='${Version} ${Status}' "$p")" = "$NEW install ok installed" ] || die "$p is not at $NEW"
done
[ "$(php -m | sort | tr '\n' ' ')" = "$MODS_BEFORE" ] || die "PHP CLI module list changed after install"
if [ "$MODPHP" = yes ]; then
  grep -aq zend_mm_safe_error_ex /usr/lib/apache2/modules/libphp7.4.so || die "libphp7.4.so lacks the fix"
  apache2ctl configtest 2>&1 | grep -q 'Syntax OK' || die "apache config test fails after install (NOT restarted)"
fi

# ---- restart so the new code is running ---------------------------------------------------
[ "$MODPHP" = yes ] && restart_apache
[ "$FPM" = yes ] && reload_fpm
[ "$MODPHP" = yes ] && { s=$(modphp_status); log "mod_php: $s"; [ "$s" = current ] || die "Apache is not running the new libphp7.4.so"; }
[ "$FPM" = yes ] && { s=$(fpm_status); log "php-fpm: $s"; [ "$s" = current ] || die "php-fpm is not running the new binary"; }
log "done: $(php -r 'echo PHP_VERSION;'). Long-running PHP CLI workers (queues, daemons) keep the old code until they restart."
