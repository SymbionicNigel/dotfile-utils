# Security

## Reporting a vulnerability

Open a [private security advisory](https://github.com/SymbionicNigel/dotfile-utils/security/advisories/new),
or email the maintainer. Please do not file public issues for security reports.

## Enabled controls

- **Secret scanning + push protection** — commits pushed with a detectable
  credential are blocked; historical leaks are flagged in the Security tab.
- **Dependabot security updates** — automatic PRs for vulnerable dependencies.
- **Branch protection on `master`** — changes land via pull request;
  force-pushes and deletions are disabled. This repo has no CI, so no status
  check is required. Admins may merge directly.
- **Merged branches are auto-deleted.**
