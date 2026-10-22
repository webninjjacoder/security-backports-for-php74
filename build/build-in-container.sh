#!/bin/bash
# Runs inside the build image. Fetches Ubuntu's php7.4 source, adds this release's
# patches (zero fuzz), prepends the changelog entry and builds every binary package.
# Output: /out/*.deb and /out/SHA256SUMS
set -euo pipefail
. /src/build/release.env

NEW_VERSION="${BASE_VERSION}+${SUFFIX}"
cd /build
apt-get update -qq
apt-get source -qq "php7.4=${BASE_VERSION}"
cd php7.4-7.4.3
head -1 debian/changelog | grep -qF "(${BASE_VERSION})" \
  || { echo "unexpected source version: $(head -1 debian/changelog)"; exit 1; }

# dpkg-source has already applied Ubuntu's own series; add ours on top, refusing any fuzz.
export QUILT_PATCHES=debian/patches QUILT_PATCH_OPTS="--fuzz=0"
while read -r p; do
  [ -n "$p" ] || continue
  quilt import "/src/${PATCH_DIR}/${p}"
  quilt push
done < "/src/${PATCH_DIR}/series"
echo "patches applied: $(quilt applied | wc -l), top: $(quilt top)"

{
  printf 'php7.4 (%s) %s-security; urgency=high\n\n' "${NEW_VERSION}" "${DISTRO}"
  printf '%s\n' "${CHANGELOG_TEXT}" | fold -s -w 72 | sed 's/ *$//; 1s/^/  * /; 2,$s/^/    /'
  printf '\n -- %s  %s\n\n' "${PACKAGER}" "${CHANGELOG_DATE}"
  cat debian/changelog
} > debian/changelog.new
mv debian/changelog.new debian/changelog
head -6 debian/changelog
[ "${PREPARE_ONLY:-0}" = 1 ] && { echo "PREPARE_ONLY: source patched and versioned, not built"; exit 0; }

# -j is deliberately not passed: it breaks make's job server in this package's rules.
DEB_BUILD_OPTIONS="nocheck parallel=$(nproc)" dpkg-buildpackage -b -uc -us

cd /build
mkdir -p /out
cp ./*_"${NEW_VERSION}"_*.deb /out/
cd /out
dpkg-deb -x "libapache2-mod-php7.4_${NEW_VERSION}_amd64.deb" /tmp/modphp
grep -aq zend_mm_safe_error_ex /tmp/modphp/usr/lib/apache2/modules/libphp7.4.so \
  || { echo "fix symbol missing from libphp7.4.so"; exit 1; }
sha256sum ./*.deb > SHA256SUMS
echo "built $(ls ./*.deb | wc -l) packages for ${NEW_VERSION}"
