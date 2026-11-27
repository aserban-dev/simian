# Coding standard

- **Followed by:** Marghioala (Developer)
- **Verified by:** Filofteia (Code Reviewer)
- **Status:** seed. Loredan (Architect) completes every rule marked **TBD** at stage 4, once the architecture fixes the stack. A TBD rule is not enforced until it is written.

## General

- **C-1** Implement only what the story's acceptance criteria ask for. Leave out extra features and unrelated refactoring.
- **C-2** Write tests first. Every acceptance criterion has at least one test that fails before the change and passes after it (see `testing.md`).
- **C-3** Any API is designed contract-first. Change the contract file (path set by the architecture, for example `api/openapi.yaml`) first, then regenerate server interfaces and clients. Never edit generated code by hand.
- **C-4** Never put secrets, keys or tokens in code, tests, fixtures or logs. Configuration comes from environment variables.
- **C-5** Code specific to one external system lives only in that system's adapter. Other code never hard-codes that system's name, URL or credentials. The list of external systems comes from configuration and `docs/source-register.md`.
- **C-6** **TBD** (Loredan (Architect), stage 4): the domain rule that matters most for this product's correctness.
- **C-7** **TBD** (Loredan (Architect), stage 4): how missing, invalid or unknown values are represented, so they are never shown as real data.
- **C-8** Each call to an external system has its own timeout and its own error handling. When one dependency fails, the product degrades for that feature only and reports the failure clearly.
- **C-9** Logs never contain personal data, tokens or secrets. **TBD** (Loredan (Architect), stage 4): the allowlist of fields that may be logged.
- **C-10** Keep diffs small and focused. Don't leave dead code, commented-out code or TODOs without a story reference.
- **C-11** Before editing a folder, read its `CLAUDE.md` if it has one.
- **C-12** Every outbound call to an external system goes through one shared client per protocol, which enforces the rules in `security-compliance.md`. Adapters never open their own connections.

## Stack-specific rules

**TBD** (Loredan (Architect), stage 4). Add one section per part of the stack, with its own prefix (for example `C-B*` for the backend, `C-W*` for web, `C-M*` for mobile): layout, dependency rules, formatter, linter, test framework, and the single command that checks that part. Record each choice in an ADR.
