# Flicko Code of Conduct

## Our Pledge

We, as members, contributors, and leaders of the Flicko project, pledge to make participation in our community a harassment-free experience for everyone, regardless of age, body size, visible or invisible disability, ethnicity, sex characteristics, gender identity and expression, level of experience, education, socio-economic status, nationality, personal appearance, race, caste, color, religion, or sexual identity and orientation.

We pledge to act and interact in ways that contribute to an open, welcoming, diverse, inclusive, and healthy community. Flicko is a communication platform built to bring people together — our development community should embody the same values of respectful and inclusive communication that we build into the product.

## Our Standards

### Positive Behaviors

Examples of behavior that contributes to a positive environment for our community include:

- **Demonstrating empathy and kindness** toward other people. When reviewing pull requests, frame feedback as suggestions rather than demands. Remember that behind every line of code is a person who invested time and effort. This is especially important in a project as complex as Flicko, where contributors may be working across unfamiliar services (Go backend, Flutter frontend, PostgreSQL/Supabase, Docker infrastructure) and may not be experts in every area.

- **Being respectful of differing opinions, viewpoints, and experiences.** Architecture decisions in Flicko (such as the 3-service split, the choice of Riverpod over Redux, or the decision to use Supabase instead of a self-hosted PostgreSQL) were made with specific trade-offs in mind. When proposing alternatives, explain the trade-offs of your approach rather than dismissing existing decisions. Constructive architectural discussions make the project better.

- **Giving and gracefully accepting constructive feedback.** Code review is an essential part of maintaining code quality across Flicko's 95+ Go service files and 51 TypeScript service files. When receiving feedback, understand that reviewers are trying to maintain consistency and quality. When giving feedback, be specific about what could be improved and why, and provide code examples when possible.

- **Accepting responsibility and apologizing to those affected by our mistakes, and learning from the experience.** In a platform that handles real-time communication and user data, mistakes in security, data handling, or privacy can have real consequences. Own your mistakes quickly, document what went wrong, and help establish processes to prevent similar issues in the future.

- **Focusing on what is best not just for us as individuals, but for the overall community.** Consider the impact of your changes on all parts of the system — a change to the message schema affects the backend services, the database migrations, the frontend stores, and the API clients. Think holistically.

- **Using welcoming and inclusive language.** Use "they/them" for unknown pronouns. Avoid jargon and acronyms without explanation, especially in documentation. Remember that contributors come from diverse technical backgrounds.

### Unacceptable Behaviors

Examples of unacceptable behavior include:

- **The use of sexualized language or imagery, and sexual attention or advances of any kind.** This applies to all project spaces including GitHub issues, pull requests, discussions, code comments, commit messages, and any community chat channels.

- **Trolling, insulting or derogatory comments, and personal or political attacks.** Disagreements about technical approaches are welcome; personal attacks are not. Criticize the code, not the person. "This approach has O(n²) complexity" is constructive; "you clearly don't understand algorithms" is not.

- **Public or private harassment.** This includes sustained disruption of discussions, unwanted following across platforms, intimidating behavior, and doxxing (sharing private information without consent).

- **Publishing others' private information**, such as email addresses, physical addresses, or identity information, without their explicit permission. This is especially important in a project that handles user communication data — take privacy seriously in all contexts.

- **Other conduct which could reasonably be considered inappropriate in a professional setting.** This includes excessive profanity in code comments, offensive variable names, inappropriate commit messages, and sharing NSFW content in any project space.

- **Submitting intentionally malicious code.** This includes backdoors, data exfiltration, credential harvesting, or any code designed to compromise the security or privacy of Flicko users. Security vulnerabilities found through honest research should be reported through our responsible disclosure process, not exploited.

## Scope

This Code of Conduct applies within all project spaces, including:

- **GitHub repository**: Issues, pull requests, discussions, wiki, code comments
- **Communication channels**: Any chat, forum, or email list associated with the project
- **Events**: Any project-related events, meetups, or conferences
- **Public representation**: When an individual is officially representing the project (e.g., using an official project email address, posting via an official social media account, or acting as an appointed representative at an event)

This Code of Conduct also applies when an individual is representing the project in public spaces. Examples include using an official project email, posting via official social media, or acting on behalf of the project at online or offline events.

## Enforcement

### Reporting

Instances of abusive, harassing, or otherwise unacceptable behavior may be reported to the project maintainers responsible for enforcement at:

- **Conduct Inquiries & Abuse Reports:** `conduct@flicko.dev` (or direct message the project maintainers via GitHub `@Santosh-Prasad-Verma`)
- **Security Vulnerabilities:** For security vulnerability disclosures, please report via [GitHub Security Advisories](https://github.com/Santosh-Prasad-Verma/Flicko/security/advisories/new)

All complaints will be reviewed and investigated promptly and fairly. The project team is obligated to maintain confidentiality with regard to the reporter of an incident.

### Enforcement Guidelines

Project maintainers will follow these Community Impact Guidelines in determining the consequences for any action they deem in violation of this Code of Conduct:

#### 1. Correction
**Community Impact:** Use of inappropriate language or other behavior deemed unprofessional or unwelcome in the community.

**Consequence:** A private, written warning from project maintainers, providing clarity around the nature of the violation and an explanation of why the behavior was inappropriate. A public apology may be requested. This is the typical response for first-time, minor violations.

#### 2. Warning
**Community Impact:** A violation through a single incident or series of actions.

**Consequence:** A warning with consequences for continued behavior. No interaction with the people involved, including unsolicited interaction with those enforcing the Code of Conduct, for a specified period of time. This includes avoiding interactions in project spaces as well as external channels like social media. Violating these terms may lead to a temporary or permanent ban.

#### 3. Temporary Ban
**Community Impact:** A serious violation of community standards, including sustained inappropriate behavior.

**Consequence:** A temporary ban from any sort of interaction or public communication with the community for a specified period of time. No public or private interaction with the people involved, including unsolicited interaction with those enforcing the Code of Conduct, is allowed during this period. Violating these terms may lead to a permanent ban. The duration of the ban will be determined by the severity of the violation and the individual's history.

#### 4. Permanent Ban
**Community Impact:** Demonstrating a pattern of violation of community standards, including sustained inappropriate behavior, harassment of an individual, or aggression toward or disparagement of classes of individuals.

**Consequence:** A permanent ban from any sort of public interaction within the project community. This includes being blocked from the GitHub organization, removal of all repository access, and prohibition from attending any project events.

## Security-Specific Guidelines

Given that Flicko is a communication platform that handles sensitive user data (messages, voice calls, media, authentication tokens), contributors must adhere to additional security-specific guidelines:

1. **Never commit credentials, API keys, or secrets** to the repository. Use environment variables as documented in [configuration.md](getting-started/configuration.md). If you accidentally commit a secret, rotate it immediately and notify the maintainers.

2. **Report security vulnerabilities responsibly.** Do not open public GitHub issues for security vulnerabilities. Instead, use GitHub's private security advisory feature or contact the maintainers directly. Provide detailed reproduction steps and, if possible, a suggested fix.

3. **Handle user data with care.** When writing test data, use clearly fake data. Never include real user information in code, documentation, or test fixtures. When debugging production issues, never share log data that could contain PII (personally identifiable information) in public channels.

4. **Follow the principle of least privilege.** When implementing features that involve permissions, default to restrictive access and require explicit permission grants. This applies to both the 26-permission RBAC system and any new permission logic.

## Attribution

This Code of Conduct is adapted from the [Contributor Covenant](https://www.contributor-covenant.org/), version 2.1, available at [https://www.contributor-covenant.org/version/2/1/code_of_conduct.html](https://www.contributor-covenant.org/version/2/1/code_of_conduct.html).

Community Impact Guidelines were inspired by [Mozilla's code of conduct enforcement ladder](https://github.com/mozilla/diversity).

For answers to common questions about this code of conduct, see the FAQ at [https://www.contributor-covenant.org/faq](https://www.contributor-covenant.org/faq). Translations are available at [https://www.contributor-covenant.org/translations](https://www.contributor-covenant.org/translations).

---

## Related Documentation

- [Contributing Guide](CONTRIBUTING.md) — How to contribute to Flicko, including development setup, code style, and PR process
- [Security: Overview](security/overview.md) — Flicko's security architecture and responsible disclosure process
- [Security: Data Protection](security/data-protection.md) — How Flicko handles user data, PII, and encryption
- [README (Documentation Hub)](README.md) — Master documentation index and project overview

## Quick Reference

| Item | Value |
|------|-------|
| **Based on** | Contributor Covenant v2.1 |
| **Scope** | All project spaces + public representation |
| **Reporting** | GitHub private advisory or maintainer contact |
| **Enforcement levels** | Correction → Warning → Temp Ban → Permanent Ban |

---

*Last Updated: 2026-04-11 | Version: 1.0.0 | Maintained by: Flicko Team*
