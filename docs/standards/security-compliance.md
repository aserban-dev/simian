# Security and compliance standard

- **Followed by:** Marghioala (Developer), Pacala (DevOps), Loredan (Architect)
- **Verified by:** Veronel (Security & Compliance)
- **Sources:** the security, privacy and compliance sections of `docs/initial-spec.md`, and `docs/source-register.md`. This file turns those sources into controls that can be checked.
- **Status:** seed. Veronel (Security & Compliance) proposes the rules marked **TBD** at stage 3 (from the PRD) and stage 4 (from the architecture); the owner approves them in a PR.

## External systems

- **S-1** Code may contact an external system (third-party API, website, SaaS, cloud service the product calls at runtime) only if it is marked **Approved** in `docs/source-register.md`. Only a human changes that status. Agents may draft a register row with Status `Proposed`, but never approve one.
- **S-2** Use each external system only within its terms of service and the access the owner approved. Never create accounts, accept terms, or obtain credentials on the owner's behalf.
- **S-3** **TBD**: usage limits per external system (rate, concurrency, quota), honoured in code through the shared client (`coding.md` C-12).
- **S-4** Honour `Retry-After`, back off exponentially on errors, and set timeouts on every outbound call.
- **S-5** If an external system blocks or throttles us, stop and flag it. Never work around a block with proxies, spoofing or impersonation.
- **S-6** **TBD**: what data from external systems may be stored, and for how long.
- **S-7** **TBD**: any further product-specific rule from the spec.
- **S-8** Each external integration can be turned off without a deploy (kill switch), through configuration the app reloads.

## Application

- **S-9** **TBD**: what personal data the product stores, where, and on what basis. Until this is written, store none. Never log IP addresses or tokens (see `coding.md` C-9).
- **S-10** Never put secrets in the repo, images, logs or infrastructure state committed to git. CI uses OIDC to reach the cloud provider and repo secrets for everything else.
- **S-11** Validate every input on the server. No input is ever placed into an outbound URL, query or command without being encoded or parameterised.
- **S-12** Pin dependency versions. CI runs a dependency vulnerability scan, and a known critical vulnerability is a blocker.
- **S-13** Serve over TLS only. Expose publicly only the ports the architecture requires. No interactive SSH from agents.

## Review duties of Veronel (Security & Compliance)

- **Stage 3 (PRD):** check that every security, privacy and compliance item in the spec is a requirement with acceptance criteria. Propose the TBD S-rules.
- **Stage 4 (architecture):** check that S-1 to S-8 are enforced in code through the shared client (`coding.md` C-12), and are not left to convention.
- **Stage 7 (diff):** check every change against S-1 to S-13. Draft rows for `docs/compliance-register.md` linking requirement, control and evidence.
