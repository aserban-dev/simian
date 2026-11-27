# simian: initial spec

> **TEMPLATE — replace every `TODO` before starting a run.** Stage 1 (Pompiliu (Analyst), product brief) starts from this file, and every later stage traces back to it. Keep it short: what and why, not how. Anything you leave open goes in §11 and is decided by the PRD (stage 3) or the architecture (stage 4).

- **Owner:** Adrian
- **Version:** TODO (for example v1)
- **Date:** TODO

## 1. Context

TODO: why this product exists, and what this project is for (a real product, a POC, a demo, a learning exercise). This decides how agents settle ambiguity.

## 2. Problem and value

TODO: the problem, who has it, and what changes for them when the product exists.

## 3. Users

TODO: the user types, with one line on what each one needs. Say if there are accounts, roles or admins.

## 4. External systems

TODO: every third-party service the product calls at runtime (APIs, identity, payments, maps, AI, websites). For each: what it is used for, and whether you have already chosen it. Each one needs a row in `docs/source-register.md` that only you can set to `Approved`. Write "none" if the product calls nothing external.

## 5. User journeys

TODO: the main journeys, step by step, from the user's point of view. The first one is the MVP.

## 6. Functional requirements

TODO: numbered (FR-1, FR-2, …), each one testable.

## 7. Non-functional requirements

TODO: numbered (NFR-1, …): performance, availability, accessibility, supported platforms and browsers, languages.

## 8. Security, privacy and compliance

TODO: what personal data is stored (or "none"), authentication, retention, any regulation that applies, and limits on how external systems may be used. Veronel (Security & Compliance) turns this section into the TBD rules in `docs/standards/security-compliance.md`.

## 9. Out of scope

TODO: what the first release deliberately does not do.

## 10. Technical decisions already made

TODO: anything fixed before architecture, such as language, framework, cloud provider, hosting, database or mobile platforms. Everything not listed here is decided by Loredan (Architect) at stage 4. Write "none" to leave it all open.

| Area | Decision | Why |
|---|---|---|
| TODO | TODO | TODO |

## 11. Open questions

TODO: what you know is undecided, and who should decide it (PRD or architecture).

## 12. Success criteria

TODO: how you will know the first release works, as observable checks.

## 13. Budget and constraints

TODO: hosting cost ceiling, deadline, and anything else that limits the design.
