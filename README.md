# Security Backports for PHP 7.4 (Ubuntu 20.04 packages)

Free, **unofficial** rebuilds of Ubuntu 20.04's `php7.4` packages with the PHP security
team's fixes for the critical, unauthenticated remote code execution bugs
**CVE-2026-109618** and **CVE-2026-109619** (PHP advisory of 21 Oct 2026). They are for
servers that run Ubuntu's PHP 7.4 and cannot use Ubuntu Pro, where Canonical ships the
official fix (`7.4.3-4ubuntu2.29+esm5`).

> **Read this first.** This project is not affiliated with, endorsed by or supported by
> the PHP Group or Canonical. The packages come with **no warranty**. You install them as
> root on your servers at your own risk. Read `install.sh` before you run it, try it on a
> staging server first, and keep the rollback copy it saves.

## What is fixed

| CVE | Severity | What it is | Fixed in |
| --- | --- | --- | --- |
| CVE-2026-109618 | Critical | RCE via out-of-memory handling during request start-up | `7.4.3-4ubuntu2.29+cve1` |
| CVE-2026-109619 | Critical | RCE via stale request state reused by a later request | `7.4.3-4ubuntu2.29+cve1` |

The packages are Ubuntu's own `7.4.3-4ubuntu2.29` source, which already carries every fix
Ubuntu shipped for 20.04 up to March 2025, plus the patch in
[`patches/`](patches/focal-7.4.3-4ubuntu2.29). They do **not** include the extra PHP fixes
that only Ubuntu Pro customers received in `+esm1` to `+esm4`; see
[Not included](#not-included).

## Is this for you?

| Your server | Use |
| --- | --- |
| Ubuntu 20.04 amd64, Ubuntu's `php7.4` (`7.4.3-4ubuntu2.x`), no Ubuntu Pro | **These packages** |
| Ubuntu 20.04 with Ubuntu Pro | `apt install --only-upgrade 'php7.4*'` (official `+esm5`) |
| PHP 7.4 from the ondrej/php PPA | Not these packages. `install.sh` refuses to run there. |
| Ubuntu 22.04 / 24.04 with Ubuntu's PHP 8.x | `apt upgrade`; the fix is in Ubuntu's normal updates |
| Anything else | Not covered |

## Install

1. **Download and check** the release bundle (`backports-…-focal-amd64.tar.gz`) from
   [Releases](../../releases):

   ```bash
   sha256sum -c backports-7.4.3-4ubuntu2.29+cve1-focal-amd64.tar.gz.sha256
   tar -xzf backports-7.4.3-4ubuntu2.29+cve1-focal-amd64.tar.gz && cd backports-*/
   sha256sum -c SHA256SUMS
   # optional: prove the packages were built by this repository's CI
   gh attestation verify php7.4-common_7.4.3-4ubuntu2.29+cve1_amd64.deb --repo webninjjacoder/security-backports-for-php74
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

3. **Verify**: `sudo ./verify.sh` must show `php7.4-common=7.4.3-4ubuntu2.29+cve1` and
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

Long-running PHP CLI processes (queue workers, daemons) keep the old code until they
restart.

## Rollback

```bash
sudo ./rollback.sh /var/backups/php74-rollback-7.4.3-4ubuntu2.29
```

This puts back Ubuntu's packages, which are vulnerable again, and restarts the web tier the
same way.

## Behaviour changes

Both come from the PHP security team's patch:

- **Session upload progress is disabled** (`session.upload_progress.*` has no effect).
- **A request that exceeds `memory_limit` ends its PHP worker immediately.** The client gets
  an empty response instead of a 500 page, and the message goes to the web server's error
  log rather than through PHP's error handler.

## How it is built and tested

- **Source:** `apt-get source php7.4=7.4.3-4ubuntu2.29` from Ubuntu's archive.
- **Patch:** [`patches/focal-7.4.3-4ubuntu2.29`](patches/focal-7.4.3-4ubuntu2.29) holds the
  PHP security team's 7.4 fix ([php-src
  712e60f](https://github.com/php/php-src/commit/712e60f9edfd03f0960fc4fc3c2c375f42b90aa2))
  applied with zero fuzz. Four hunks are left out because Ubuntu's source already contains
  that code (`max_multipart_body_parts`, from its CVE-2023-0662 patches); the patch header
  says which.
- **Build:** [`build/build.sh`](build/build.sh) runs everything in an Ubuntu 20.04 container.
  Releases are built by [GitHub Actions](.github/workflows/build.yml) on GitHub's runners,
  with a build provenance attestation for every package.
- **Tests:** [`tests/compare.sh`](tests/compare.sh) installs stock Ubuntu PHP and then these
  packages in a fresh container under Apache mod_php, and compares them on two things:
  - A request suite covering query arrays, cookies, URL-encoded and multipart posts, file
    uploads, duplicate multipart headers, 3,000-field forms, basic auth, sessions and an
    over-limit request.
  - About 6,200 of PHP's own tests from `Zend/tests`, `tests/`, `ext/session`, `ext/json`,
    `ext/mbstring` and parts of `ext/standard`.

  A release passes only if the sole differences are the two behaviour changes above: 8
  `ext/session/tests/rfc1867*.phpt` tests and `tests/lang/bug45392.phpt`. Each release
  attaches its test results.
- **In use:** builds from this same source and patch have run on six Ubuntu 20.04 web
  servers (Apache mod_php), five of them in production, since 22 Oct 2026.

Build and test it yourself:

```bash
build/build.sh out          # ~30–60 min on x86-64; roughly double under emulation
tests/compare.sh out results
tests/install-test.sh out   # install.sh -> verify.sh -> rollback.sh on a clean container
```

## Not included

Ubuntu Pro's `+esm1` to `+esm4` updates fix further PHP 7.4 issues that these packages
do not (yet) cover. The planned next release adds two of them:

- CVE-2025-14181: SOAP client heap overflow from a malicious server.
- CVE-2026-91769: TLS peer name accepted via the certificate's Common Name despite
  non-matching subjectAltNames.

The rest: CVE-2025-1220, CVE-2025-1735, CVE-2025-6491, CVE-2025-14178, CVE-2025-14180,
CVE-2025-1218, CVE-2026-6103, CVE-2026-91765, CVE-2026-91766, CVE-2026-91767,
CVE-2026-91768, CVE-2026-92842, CVE-2026-93682. Ubuntu 20.04 without Ubuntu Pro also
receives no other operating-system security updates since May 2025.

## Moving to Ubuntu Pro later

The version suffix `+cve1` sorts after Ubuntu's `7.4.3-4ubuntu2.29` and before Ubuntu
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
