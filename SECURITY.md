# Security Policy

## Supported Versions
We aim to keep main and the latest tagged release secure. Older releases may not receive security updates.

## Reporting a Vulnerability
Please report suspected vulnerabilities privately.
- Email: john.alcorn@kyndryl.com
- Subject: [Security - Stock Trader] <short description>
- Include: affected versions/commit, reproduction steps, impact, and any logs (redact secrets)

We will acknowledge receipt within 3 business days and provide a remediation timeline after triage.

## Scope
- Terraform code in this repository
- Provided scripts (e.g., precheck.sh)
- Kubernetes and Istio manifests/templates included here

## Out of Scope
- Third-party providers, Azure platform services, and external dependencies
- Misconfigurations outside the documented usage

## Disclosure
Once a fix is available, we will publish a security advisory with mitigation steps and credit reporters who wish to be acknowledged.


