#!/bin/bash
# Runs inside a fresh ubuntu:20.04 container (started with --init by tests/compare.sh).
# 1. stock Ubuntu php7.4 + Apache mod_php: request suite + PHP's own test subset
# 2. install the patched packages, FULL Apache restart, confirm the new libphp is mapped
# 3. same tests again; fail on any difference that the fix does not explain
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8
. /src/build/release.env
NEW="${BASE_VERSION}+${SUFFIX}"
R=/results; mkdir -p "$R"
PKGS="libapache2-mod-php7.4 php7.4 php7.4-cli php7.4-common php7.4-cgi php7.4-curl php7.4-gd php7.4-json
      php7.4-mbstring php7.4-mysql php7.4-opcache php7.4-readline php7.4-soap php7.4-xml php7.4-zip"

printf '%s\n' \
  'deb http://archive.ubuntu.com/ubuntu focal main restricted universe multiverse' \
  'deb http://archive.ubuntu.com/ubuntu focal-updates main restricted universe multiverse' \
  'deb http://security.ubuntu.com/ubuntu focal-security main restricted universe multiverse' \
  'deb-src http://archive.ubuntu.com/ubuntu focal-updates main restricted universe multiverse' \
  'deb-src http://security.ubuntu.com/ubuntu focal-security main restricted universe multiverse' \
  > /etc/apt/sources.list
rm -f /usr/sbin/policy-rc.d
apt-get update -qq
apt-get install -y -qq --no-install-recommends apache2 curl python3 ca-certificates dpkg-dev \
  $(for p in $PKGS; do printf '%s=%s ' "$p" "$BASE_VERSION"; done) php-redis php-igbinary >/dev/null

# production-like settings
INI=/etc/php/7.4/apache2/php.ini
sed -i -E 's/^memory_limit = .*/memory_limit = 1024M/; s/^post_max_size = .*/post_max_size = 100M/;
  s/^upload_max_filesize = .*/upload_max_filesize = 100M/; s/^;?max_input_vars = .*/max_input_vars = 100000/' "$INI"
a2dismod -q mpm_event >/dev/null 2>&1 || true; a2enmod -q mpm_prefork php7.4 >/dev/null
mkdir -p /var/www/html/t && cp /src/tests/web/*.php /var/www/html/t/

# PHP's own tests, from the same Ubuntu source
cd /tmp && apt-get source -qq --download-only "php7.4=${BASE_VERSION}" >/dev/null && dpkg-source -x -q php7.4_*.dsc phpsrc >/dev/null
SUITES="Zend/tests tests ext/session/tests ext/standard/tests/array ext/standard/tests/strings ext/standard/tests/serialize ext/standard/tests/general_functions ext/json/tests ext/mbstring/tests"
phpt() { # $1 = label
  ( cd /tmp/phpsrc && NO_INTERACTION=1 REPORT_EXIT_STATUS=0 SKIP_SLOW_TESTS=1 SKIP_ONLINE_TESTS=1 \
    TEST_PHP_EXECUTABLE=/usr/bin/php7.4 TEST_PHP_CGI_EXECUTABLE=/usr/bin/php-cgi7.4 \
    php7.4 run-tests.php -q -j"$(nproc)" -d memory_limit=512M --set-timeout 120 -s "$R/phpt-$1.log" $SUITES >/dev/null 2>&1 || true )
  sed -n '/^FAILED TEST SUMMARY/,/^====/p' "$R/phpt-$1.log" | grep -oE '\[[^]]+\.phpt\]' | sort -u > "$R/phpt-$1-failed.txt"
}
norm() { sed -E 's/boundary=-+[0-9a-f]+/boundary=X/' "$1"; }
modphp_mapped() { grep -m1 'libphp7.4.so' "/proc/$(cat /run/apache2/apache2.pid)/maps"; }

# ---- stock ----
apachectl start 2>/dev/null; sleep 3
bash /src/tests/run-requests.sh > "$R/requests-stock.txt" 2>&1
phpt stock

# ---- patched ----
dpkg -i --force-confold $(for p in $PKGS; do ls "/debs/${p}_${NEW}_"*.deb; done) > "$R/install.log" 2>&1
OLD=$(cat /run/apache2/apache2.pid); apachectl stop
while kill -0 "$OLD" 2>/dev/null; do sleep 0.2; done
apachectl start 2>/dev/null; sleep 3
modphp_mapped | tee "$R/modphp-mapping.txt"
grep -q deleted "$R/modphp-mapping.txt" && { echo "FAIL: Apache still maps the old libphp7.4.so"; exit 1; }
bash /src/tests/run-requests.sh > "$R/requests-patched.txt" 2>&1
phpt patched

# ---- verdict ----
fail=0
# Only the over-memory_limit request may differ: the fix ends the worker instead of returning a 500.
diff <(norm "$R/requests-stock.txt" | sed '/^## oom/,/^## after-oom/{/^http=\|^curl_exit=/d}') \
     <(norm "$R/requests-patched.txt" | sed '/^## oom/,/^## after-oom/{/^http=\|^curl_exit=/d}') \
     > "$R/requests.diff" || { echo "FAIL: request results differ (see requests.diff)"; fail=1; }
grep -q '^http=000' "$R/requests-patched.txt" || { echo "FAIL: memory-limit request did not end the worker as the fix should"; fail=1; }
comm -13 "$R/phpt-stock-failed.txt" "$R/phpt-patched-failed.txt" > "$R/phpt-new-failures.txt"
# Expected: upload progress is disabled by the fix; memory-limit message gains a leading newline.
grep -vE '^\[(ext/session/tests/rfc1867[a-z0-9_]*\.phpt|tests/lang/bug45392\.phpt)\]$' "$R/phpt-new-failures.txt" \
  > "$R/phpt-unexpected.txt" || true
[ -s "$R/phpt-unexpected.txt" ] && { echo "FAIL: unexpected new test failures:"; cat "$R/phpt-unexpected.txt"; fail=1; }
{
  echo "stock:   $(grep -E '^Tests (passed|failed)' "$R/phpt-stock.log" | tr -s ' ' | tr '\n' ' ')"
  echo "patched: $(grep -E '^Tests (passed|failed)' "$R/phpt-patched.log" | tr -s ' ' | tr '\n' ' ')"
  echo "new failures (all expected): $(wc -l < "$R/phpt-new-failures.txt")"
} | tee "$R/summary.txt"
[ "$fail" = 0 ] && echo "PASS" | tee -a "$R/summary.txt"
exit "$fail"
