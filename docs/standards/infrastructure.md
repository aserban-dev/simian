# Infrastructure standard

- **Followed by:** Pacala (DevOps)
- **Verified by:** Veronel (Security & Compliance), plus `terraform plan` in CI
- **Status:** seed. The deployment target is not decided yet. Loredan (Architect) decides it at stage 4 (ADR) and completes every rule marked **TBD**.

- **I-1** Every cloud resource is defined as code (Terraform or OpenTofu) under `infra/`. Nothing is created or changed by hand in a console.
- **I-2** Every PR that touches `infra/` runs `fmt -check`, `validate` and `plan`, and the plan is attached to the PR. **Only a human runs `apply`.** Agents never do.
- **I-3** **TBD**: the deployment target (provider, region, compute model) and the network rules (which ports are public).
- **I-4** Infrastructure state is kept in a remote backend with locking. State files are never committed.
- **I-5** GitHub Actions authenticates to the cloud provider through OIDC. No long-lived cloud credentials are stored anywhere.
- **I-6** **TBD**: how the app is packaged and run (for example containers with pinned image tags, never `latest`).
- **I-7** Deployment happens only from GitHub Actions, after a merge to `main`. Agents never deploy or open remote sessions.
- **I-8** Every resource is tagged `project=simian` and `env=<env>`. A cost alert is set at the owner's ceiling.
- **I-9** Kill switches and integration config live in configuration the app reloads without a deploy (`security-compliance.md` S-8).
- **I-10** **TBD**: health checks and monitoring, and what they do on failure (for example open an issue).
