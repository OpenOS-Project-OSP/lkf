# Security Policy

## Supported versions

Only the latest release is supported with security fixes.

| Version | Supported |
|---------|-----------|
| 0.1.x   | ✅        |

## Reporting a vulnerability

**Do not open a public issue for security vulnerabilities.**

Report privately via GitHub's built-in mechanism:
[Report a vulnerability](https://github.com/Interested-Deving-1896/lkf/security/advisories/new)

Include:
- A description of the vulnerability and its impact
- Steps to reproduce
- Any suggested fix or mitigation

You will receive a response within 7 days. If the issue is confirmed, a fix
will be released as soon as practical and credited to you in the changelog
unless you prefer to remain anonymous.

## Scope

lkf is a build-system framework that runs as the invoking user. It does not
run as root except where explicitly requested (e.g. `sudo` calls in
`lkf toolchain install-deps`). The primary security concerns are:

- **Patch authenticity** — `lkf patch fetch` downloads patches from upstream
  repositories over HTTPS. Use `lkf build --verify-gpg` to verify kernel
  tarballs against kernel.org GPG signatures.
- **Arbitrary code execution** — `remix.toml` files are parsed and their
  fields passed to shell commands. Do not use `remix.toml` files from
  untrusted sources.
- **Credential exposure** — `GITHUB_TOKEN` is used only for GitHub API rate
  limiting in `patches/fetch.sh`. It is never logged or written to disk.
