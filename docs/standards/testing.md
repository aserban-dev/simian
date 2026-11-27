# Testing standard

- **Followed by:** Eufrosina (QA) and Marghioala (Developer)
- **Verified by:** Filofteia (Code Reviewer) and CI
- **Status:** seed. Eufrosina (QA) completes the rules marked **TBD** during stage 6 or the first epic, once the test framework is set up.

- **T-1** Every acceptance criterion has at least one test. The test's name or tag includes the acceptance criterion's ID, so that the traceability matrix can be generated.
- **T-2** Integrations with external systems are tested against recorded fixtures or stubs in `fixtures/<system>/`. A fixture holds only the facts the test needs, with no personal data and no secrets.
- **T-3** CI never calls a real external system. Live calls happen only in an explicitly scheduled health check, if the architecture defines one.
- **T-4** **TBD** (Eufrosina (QA)): the end-to-end tests that cover the product's main journeys from the PRD, and the tool that runs them (configured in TEA).
- **T-5** Tests are deterministic. They use no `sleep` calls and no reliance on wall-clock time or test order. Time and randomness are injected.
- **T-6** Every bug fix starts with a test that reproduces the bug.
- **T-7** **TBD** (Eufrosina (QA)): the input-validation cases every user-facing input must be tested on.
- **T-8** The test commands are listed in the `sdlc-commands` block of the root `AGENTS.md`. Zamolxe (Orchestrator) runs exactly those commands at the "tests pass" gate.
