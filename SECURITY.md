# Security policy

## Reporting a problem with these packages

If you find a security problem in the patches, the build or the install scripts, report it
privately via GitHub: **Security → Report a vulnerability** on this repository. Please do
not open a public issue for it.

Include the release, what you found, and how to reproduce it if you can. This is a
best-effort personal project: expect an acknowledgement within a few days, not hours.

## Vulnerabilities in PHP itself

Report those to the PHP project, not here: <https://github.com/php/php-src/security>.

## What this project does and does not promise

- Each release states exactly which CVEs it fixes (see the README and `CHANGELOG.md`).
- Packages are built by this repository's GitHub Actions workflow, and each release
  includes build provenance attestations and SHA-256 checksums.
- There is no warranty and no guaranteed response time. For a supported, official fix,
  use Ubuntu Pro.
