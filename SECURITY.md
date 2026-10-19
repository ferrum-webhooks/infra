# Security policy

This is a portfolio/learning project, not a supported product. Please do not deploy it as-is to protect real data.

**Reporting a vulnerability:** open a private security advisory on the repository (Security tab → "Report a vulnerability"), or contact the maintainer through the email on their GitHub profile. Please do not file public issues for security problems.

Known limitations (no TLS between components, plaintext webhook signing secrets in the database, shared-secret JWT without revocation, a documented DNS-rebinding window in the SSRF guard) are listed in `docs/security.md` of the umbrella repository; reports about those are welcome as improvements, not as new vulnerabilities.

**Secrets:** no real credentials are committed. All values in `*.example` files and Kubernetes templates are placeholders (`CHANGE_ME`).
