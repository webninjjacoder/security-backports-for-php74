#!/bin/bash
# Puts back the packages install.sh saved and restarts the PHP web tier the same way.
#   sudo ./rollback.sh /var/backups/php74-rollback-<previous-version>
set -euo pipefail
export LC_ALL=C DEBIAN_FRONTEND=noninteractive
. "$(dirname "$0")/lib.sh"

BACKUP=$(cd "${1:?usage: rollback.sh /var/backups/php74-rollback-<version>}" && pwd)
[ "$(id -u)" = 0 ] || die "run as root"
ls "$BACKUP"/*.deb >/dev/null 2>&1 || die "no packages in $BACKUP"

MODPHP=no; FPM=no
uses_modphp && MODPHP=yes
uses_fpm && FPM=yes

block_service_restarts
dpkg -i --force-confold "$BACKUP"/*.deb > /var/log/php74-backport-rollback.log 2>&1 \
  || { tail -20 /var/log/php74-backport-rollback.log; die "dpkg -i failed; see /var/log/php74-backport-rollback.log"; }
allow_service_restarts

[ "$MODPHP" = yes ] && { apache2ctl configtest; restart_apache; }
[ "$FPM" = yes ] && reload_fpm
log "rolled back to $(dpkg-query -W -f='${Version}' php7.4-common)"
