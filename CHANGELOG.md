# Changelog

## 7.4.3-4ubuntu2.29+cve2 (release tag v7.4.3-4ubuntu2.29-cve2, 23 Oct 2026)

- Keeps the `+cve1` fix for **CVE-2026-109618** and **CVE-2026-109619**.
- Backports the 14 PHP 7.4 fixes that Ubuntu Pro ships in `+esm1` to `+esm4`:
  - CVE-2025-1218 (mysqlnd)
  - CVE-2025-14181, CVE-2025-6491 and CVE-2026-91765 (SOAP)
  - CVE-2026-91769 and CVE-2026-91767 (TLS)
  - CVE-2026-91766 and CVE-2026-93682 (HTTP stream redirects)
  - CVE-2025-1220 (sockets)
  - CVE-2025-14178 (arrays)
  - CVE-2026-92842 (stream filters)
  - CVE-2026-6103 (Phar)
  - CVE-2025-1735 (PostgreSQL)
  - CVE-2026-91768 (PHP-FPM)
- CVE-2025-14177 and CVE-2025-14180 do not affect PHP 7.4, so no change was needed.
- **Sources:** Debian bullseye LTS's PHP 7.4 patches where available; otherwise Ubuntu
  22.04's PHP 8.1 patches, ported to 7.4. Each patch header documents its source and any
  change.
- **New behaviour:**
  - stricter TLS name checks;
  - credentials stripped on cross-origin HTTP redirects;
  - a SOAP response that announces an absurd size hits `memory_limit` instead of
    returning a `SoapFault`.
- `install.sh` now saves the previous `+cveN` packages as its rollback copy. Pass them with
  `ROLLBACK_SOURCES`, and the script refuses rather than falling back to a vulnerable
  stock build.

## 7.4.3-4ubuntu2.29+cve1 (release tag v7.4.3-4ubuntu2.29-cve1, 22 Oct 2026)

- Fixes **CVE-2026-109618** and **CVE-2026-109619**: critical, unauthenticated remote code
  execution (PHP security advisory of 21 Oct 2026). Backport of php-src commit 712e60f, the
  PHP security team's minimal mitigation for PHP 7.4, onto Ubuntu 20.04's
  `php7.4 7.4.3-4ubuntu2.29`.
- Behaviour changes from the fix: session upload progress is disabled, and a request over
  `memory_limit` ends its worker (empty response instead of a 500).
- After installing, Apache must be fully stopped and started (not gracefully reloaded) for
  the fix to take effect; `install.sh` does this.
