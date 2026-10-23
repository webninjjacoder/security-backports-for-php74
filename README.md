# Security Backports for PHP 7.4 (Ubuntu 20.04 packages)

Free, **unofficial** rebuilds of Ubuntu 20.04's `php7.4` packages with security fixes that
Ubuntu ships only to Ubuntu Pro customers. The current release, `7.4.3-4ubuntu2.29+cve2`,
fixes the critical unauthenticated remote code execution bugs **CVE-2026-109618** and
**CVE-2026-109619** (PHP advisory of 21 Oct 2026) and backports **14 further PHP 7.4
fixes** from Ubuntu Pro's `+esm1` to `+esm4` updates. It is for servers that run Ubuntu's
PHP 7.4 and cannot use Ubuntu Pro, where Canonical ships the official fixes.

> **Read this first.** This project is not affiliated with, endorsed by or supported by
> the PHP Group or Canonical. The packages come with **no warranty**. You install them as
> root on your servers at your own risk. Read `install.sh` before you run it, try it on a
> staging server first, and keep the rollback copy it saves.

## What is fixed

| CVE | Area | What it is | Fixed in |
| --- | --- | --- | --- |
| CVE-2026-109618 | Core | **Critical.** RCE via out-of-memory handling during request start-up | `+cve1` |
| CVE-2026-109619 | Core | **Critical.** RCE via stale request state reused by a later request | `+cve1` |
| CVE-2025-1218 | mysqlnd | A malicious MySQL server can make PHP read past packet buffers | `+cve2` |
| CVE-2025-14181 | SOAP client | Heap overflow from a malicious SOAP server's chunked response | `+cve2` |
| CVE-2025-6491 | SOAP | Crash on an over-long namespace prefix | `+cve2` |
| CVE-2026-91765 | SOAP | Unbounded recursion on deeply nested SOAP data | `+cve2` |
| CVE-2026-91769 | TLS | Certificate accepted by its Common Name although its subjectAltNames do not match | `+cve2` |
| CVE-2026-91767 | TLS | Out-of-bounds read when matching some wildcard certificate names | `+cve2` |
| CVE-2026-91766 | HTTP streams | Authorization and Cookie headers kept on a cross-origin redirect | `+cve2` |
| CVE-2026-93682 | HTTP streams | Out-of-bounds read on an empty or 1-character `Location` header | `+cve2` |
| CVE-2025-1220 | Sockets | Hostnames with null bytes accepted by `fsockopen` and socket transports | `+cve2` |
| CVE-2025-14178 | Arrays | Element count overflow | `+cve2` |
| CVE-2026-92842 | Stream filters | Over-read in the `line-break-chars` filter option | `+cve2` |
| CVE-2026-6103 | Phar | Crafted tar archives can inject entries | `+cve2` |
| CVE-2025-1735 | PostgreSQL | Escaping errors not handled | `+cve2` |
| CVE-2026-91768 | PHP-FPM | IPv6 addresses not checked correctly against `listen.allowed_clients` | `+cve2` |

**Not affected in 7.4, so no code change:**

- **CVE-2025-14177:** Ubuntu marks php7.4 as not affected.
- **CVE-2025-14180:** in PHP 7.4 the PDO quoter's failure is already checked. Debian's LTS
  team reached the same conclusion.

The packages are Ubuntu's own `7.4.3-4ubuntu2.29` source, which already carries every fix
Ubuntu shipped for 20.04 up to March 2025, plus the patches in
[`patches/`](patches/focal-7.4.3-4ubuntu2.29).

## Is this for you?

| Your server | Use |
| --- | --- |
| Ubuntu 20.04 amd64, Ubuntu's `php7.4` (`7.4.3-4ubuntu2.x`), no Ubuntu Pro | **These packages** |
| Ubuntu 20.04 with Ubuntu Pro | `apt install --only-upgrade 'php7.4*'` (official `+esm5`) |
| PHP 7.4 from the ondrej/php PPA | Not these packages. `install.sh` refuses to run there. |
| Ubuntu 22.04 / 24.04 with Ubuntu's PHP 8.x | `apt upgrade`; the fixes are in Ubuntu's normal updates |
| Anything else | Not covered |

## Install

1. **Download and check** the release bundle (`backports-…-focal-amd64.tar.gz`) from
   [Releases](../../releases):

   ```bash
   V=7.4.3-4ubuntu2.29+cve2
   sha256sum -c backports-$V-focal-amd64.tar.gz.sha256
   tar -xzf backports-$V-focal-amd64.tar.gz && cd backports-$V-focal-amd64
   sha256sum -c SHA256SUMS
   # optional: prove the packages were built by this repository's CI
   gh attestation verify php7.4-common_${V}_amd64.deb --repo webninjjacoder/security-backports-for-php74
   ```

2. **Install** (staging first, then one server at a time):

   ```bash
   sudo ./install.sh .
   ```

   The script checks that this server is Ubuntu 20.04 with Ubuntu's `php7.4`. It saves the
   currently installed packages to `/var/backups/php74-rollback-<version>`, then installs
   only the `php7.4*` packages already present, with `dpkg -i` and service restarts
   blocked. Finally it restarts Apache (mod_php) and/or reloads PHP-FPM and checks that
   they now run the new code.

   **Upgrading from `+cve1`?** `+cve1` is not in Ubuntu's archive, so tell the script where
   the previous release's packages are, for its rollback copy:

   ```bash
   sudo ROLLBACK_SOURCES=/path/to/backports-7.4.3-4ubuntu2.29+cve1-focal-amd64 ./install.sh .
   ```

   Without it the script stops before changing anything, rather than saving a vulnerable
   stock build as the rollback target.

3. **Verify**: `sudo ./verify.sh` must show `php7.4-common=7.4.3-4ubuntu2.29+cve2` and
   `mod_php=current` and/or `php-fpm=current` (`STALE` means the old code is still running).

### Why the web server must really restart

Installing the packages is not enough. After `apachectl graceful`, Apache keeps the **old**
`libphp7.4.so` in memory, and `php -v` already shows the new version. The server *looks*
patched while it still runs the vulnerable code. `install.sh` therefore stops Apache
gracefully, gives running requests up to 5 seconds, and starts it again. That closes the
port for about 1–6 seconds. Behind a load balancer with more than one server, do one server
at a time.

On Google Cloud managed instance groups (and similar auto-healing setups), avoid
`systemctl restart apache2`. On many systems its stop step waits for the slowest request,
up to 90 s, which can be long enough for health checks to fail and the VM to be recreated
from its old, unpatched image. Also remember to update the images your instance templates
use.

Long-running PHP CLI processes keep the old code until they restart. That includes queue
workers such as Laravel Horizon (`php artisan horizon:terminate`) and daemons.

## Rollback

```bash
sudo ./rollback.sh /var/backups/php74-rollback-<previous-version>
```

This puts back the saved packages and restarts the web tier the same way. If that is
Ubuntu's stock build, it is vulnerable again.

## Behaviour changes

All of these come from the upstream fixes:

- **Session upload progress is disabled** (`session.upload_progress.*` has no effect).
- **A request that exceeds `memory_limit` ends its PHP worker immediately.** The client gets
  an empty response instead of a 500 page, and the message goes to the web server's error
  log.
- **TLS:** a certificate whose subjectAltNames do not match the requested name is now
  rejected even if its Common Name matches. Certificates without any subjectAltName still
  fall back to the Common Name. Public CA certificates always carry the name in their
  subjectAltNames, so this affects only unusual private certificates.
- **SOAP client:** a server that announces an absurdly large chunked response now makes the
  request hit `memory_limit` instead of returning a `SoapFault`.
- **HTTP stream redirects:** `Authorization`, `Cookie` and (without a proxy)
  `Proxy-Authorization` headers are no longer sent on to a different scheme, host or port.

## How it is built and tested

- **Source:** `apt-get source php7.4=7.4.3-4ubuntu2.29` from Ubuntu's archive.
- **Patches:** [`patches/focal-7.4.3-4ubuntu2.29`](patches/focal-7.4.3-4ubuntu2.29), applied
  in `series` order with zero fuzz. Each header says where the patch comes from:
  - Debian bullseye LTS's PHP 7.4 security updates, used unchanged where they exist;
  - Ubuntu 22.04's PHP 8.1 patches;
  - the PHP security team's own 7.4 fix.

  Each header also says what had to change for PHP 7.4, for example `zend_bool` for `bool`,
  or context lines.
- **Build:** [`build/build.sh`](build/build.sh) runs everything in an Ubuntu 20.04 container.
  Releases are built by [GitHub Actions](.github/workflows/build.yml) on GitHub's runners,
  with a build provenance attestation for every package.
- **Tests on every release:** [`tests/compare.sh`](tests/compare.sh) installs stock Ubuntu
  PHP and then these packages in a fresh container under Apache mod_php, and compares them
  on two things:
  - A request suite covering query arrays, cookies, URL-encoded and multipart posts, file
    uploads, duplicate multipart headers, 3,000-field forms, basic auth, sessions and an
    over-limit request.
  - About 6,200 of PHP's own tests. Only differences explained by the fixes are allowed.

  [`tests/install-test.sh`](tests/install-test.sh) exercises `install.sh`, `verify.sh` and
  `rollback.sh`.
- **Per-CVE evidence for `+cve2`:** see the table below.

| Proof | CVEs |
| --- | --- |
| Upstream regression test **fails on `+cve1`, passes on `+cve2`** | CVE-2026-6103, CVE-2026-91765, CVE-2025-6491, CVE-2025-14178, CVE-2026-92842, CVE-2025-1220 |
| Own test: TLS certificate matrix, rejected on `+cve2` only where expected | CVE-2026-91769, CVE-2026-91767 |
| Fix code present in the build; normal paths tested, but the attack test not yet run on 7.4 | CVE-2025-1218 (its 38 tests need a PHP 8 fake MySQL server), CVE-2026-91766 and CVE-2026-93682 (their tests need PHP 8's test server), CVE-2025-14181 (needs 4 GB RAM) |
| Fix code present; component not exercised | CVE-2025-1735 (PostgreSQL), CVE-2026-91768 (PHP-FPM) |

- **In use:** builds from this same source and patch set run on nine Ubuntu 20.04 web servers
  (Apache mod_php), seven of them in production, since 22 Oct 2026 (`+cve2` since 22 Oct,
  about 22:30 UTC).

Build and test it yourself:

```bash
build/build.sh out          # ~30–60 min on x86-64; roughly double under emulation
tests/compare.sh out results
tests/install-test.sh out   # install.sh -> verify.sh -> rollback.sh on a clean container
```

## Not included

Ubuntu 20.04 without Ubuntu Pro receives no other operating-system security updates since
May 2025. These packages fix PHP only. Other PHP 7.4 issues may be found later; watch this
repository's releases.

## Moving to Ubuntu Pro later

The version suffix `+cveN` sorts after Ubuntu's `7.4.3-4ubuntu2.29` and before Ubuntu
Pro's `+esmN`. If you attach Ubuntu Pro, `apt` replaces these packages with Canonical's by
itself.

## Support

Best effort, no warranty and no guaranteed timelines. Open an issue for problems with the
packages. Report security problems privately as described in [SECURITY.md](SECURITY.md).

## License and trademarks

- **The patches** in `patches/` are derived from PHP and are under the
  [PHP License v3.01](https://www.php.net/license/3_01.txt).
- **The built packages** contain PHP (PHP License v3.01) and Ubuntu's packaging, whose terms
  are in each package's `/usr/share/doc/*/copyright`.
- **Everything else** (scripts, tests, docs) is under the MIT License; see [LICENSE](LICENSE).

"PHP" is used here only to say what these packages are for. Ubuntu is a trademark of
Canonical Ltd. Neither the PHP Group nor Canonical endorses this project.
