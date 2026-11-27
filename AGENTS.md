# Repository guidance

Follow [Workstation Philosophy](docs/workstation-philosophy.md): native first,
consistent workflows, minimal complexity. Read the relevant platform guide
and existing implementation before making changes. Keep changes scoped to the
requested platform and preserve working behavior on the other platforms.
Separate verified behavior from proposed experiments; test drift detection,
installation and idempotency where applicable. Never silently replace user
configuration or remove installed tools merely to achieve uniformity.

This repository owns system installation, package manifests, desktop integration
and workstation restore. Keep shared user configuration in `dotfiles`. Use
`test/lint.sh` and the focused regression tests for changed scripts. Record
real-machine experiments and limitations in `docs/worklog/`.
