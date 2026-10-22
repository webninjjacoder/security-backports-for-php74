# Changelog

## 7.4.3-4ubuntu2.29+cve1 (release tag v7.4.3-4ubuntu2.29-cve1, 22 Oct 2026)

- Fixes **CVE-2026-109618** and **CVE-2026-109619**: critical, unauthenticated remote code
  execution (PHP security advisory of 21 Oct 2026). Backport of php-src commit 712e60f, the
  PHP security team's minimal mitigation for PHP 7.4, onto Ubuntu 20.04's
  `php7.4 7.4.3-4ubuntu2.29`.
- Behaviour changes from the fix: session upload progress is disabled, and a request over
  `memory_limit` ends its worker (empty response instead of a 500).
- After installing, Apache must be fully stopped and started (not gracefully reloaded) for
  the fix to take effect; `install.sh` does this.
