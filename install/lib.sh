#!/bin/bash
# Shared helpers for install.sh / rollback.sh. Sourced, not run.

log() { echo "[$(date +%T)] $*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

# true while a PID exists and is not a zombie
alive() { [ -e "/proc/$1" ] && ! grep -q '^State:.*Z' "/proc/$1/status" 2>/dev/null; }

uses_modphp() {
  systemctl is-active --quiet apache2 2>/dev/null \
    && [ -e /usr/lib/apache2/modules/libphp7.4.so ] \
    && apache2ctl -M 2>/dev/null | grep -q 'php7_module'
}
uses_fpm() { systemctl is-active --quiet php7.4-fpm 2>/dev/null; }

POLICY=/usr/sbin/policy-rc.d
block_service_restarts() {
  [ -e "$POLICY" ] && die "$POLICY already exists; refusing to overwrite it"
  printf '#!/bin/sh\nexit 101\n' > "$POLICY"; chmod 755 "$POLICY"
  trap 'rm -f "$POLICY"' EXIT
}
allow_service_restarts() { rm -f "$POLICY"; trap - EXIT; }

# Apache + mod_php. A graceful reload keeps the OLD libphp7.4.so mapped in the parent
# (and every worker forked from it), so a full stop/start is required. Not
# `systemctl restart`: on many systems its ExecStop is graceful-stop, which keeps port 80
# closed until the slowest request ends (up to 90 s) and can trip load-balancer
# auto-healing. Instead: graceful-stop, give in-flight requests up to 5 s, then start.
restart_apache() {
  local old t0 t1
  old=$(cat /run/apache2/apache2.pid)
  t0=$(date +%s.%N)
  log "apache: graceful-stop (port closes now; in-flight requests get up to 5 s)"
  apachectl graceful-stop
  for _ in $(seq 1 50); do alive "$old" || break; sleep 0.1; done
  if alive "$old"; then
    log "apache: requests still running after 5 s -> SIGTERM old parent"
    kill -TERM "$old" 2>/dev/null || true
    for _ in $(seq 1 30); do alive "$old" || break; sleep 0.1; done
  fi
  for _ in $(seq 1 20); do systemctl is-active --quiet apache2 || break; sleep 0.1; done
  systemctl start apache2 || { sleep 1; systemctl start apache2 || true; }
  t1=$(date +%s.%N)
  systemctl is-active --quiet apache2 || die "apache2 is DOWN after restart: run 'systemctl start apache2' now"
  for _ in $(seq 1 50); do [ -s /run/apache2/apache2.pid ] && break; sleep 0.1; done
  log "apache: back after $(awk "BEGIN{printf \"%.2f\", $t1-$t0}") s"
}

# PHP-FPM: a reload (SIGUSR2) re-executes the master with the new binary.
reload_fpm() {
  log "php-fpm: reload"
  systemctl reload php7.4-fpm
  sleep 2
  if [ "$(fpm_status)" = STALE ]; then
    log "php-fpm: master still runs the old binary -> restart"
    systemctl restart php7.4-fpm
    sleep 2
  fi
}

# Prints "current" (running the installed code), "STALE" (old code still loaded,
# restart needed) or "not-loaded".
modphp_status() {
  local pid maps
  pid=$(cat /run/apache2/apache2.pid 2>/dev/null) || { echo not-loaded; return; }
  maps=$(grep -m1 'libphp7.4.so' "/proc/$pid/maps" 2>/dev/null)
  if [ -z "$maps" ]; then echo not-loaded
  elif echo "$maps" | grep -q deleted; then echo STALE
  else echo current; fi
}
fpm_status() {
  local pid exe
  pid=$(cat /run/php/php7.4-fpm.pid 2>/dev/null) || { echo not-loaded; return; }
  exe=$(readlink "/proc/$pid/exe" 2>/dev/null)
  if [ -z "$exe" ]; then echo not-loaded
  elif echo "$exe" | grep -q deleted; then echo STALE
  else echo current; fi
}
