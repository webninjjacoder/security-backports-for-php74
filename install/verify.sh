#!/bin/bash
# Read-only. Shows whether the running PHP web processes use the installed (patched) code.
# The package version alone proves nothing: until the web tier restarts, the old code runs.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
printf 'host=%s php7.4-common=%s cli=%s' "$(hostname)" \
  "$(dpkg-query -W -f='${Version}' php7.4-common 2>/dev/null)" "$(php -r 'echo PHP_VERSION;' 2>/dev/null)"
uses_modphp && printf ' mod_php=%s' "$(modphp_status)"
uses_fpm && printf ' php-fpm=%s' "$(fpm_status)"
printf '\n'
