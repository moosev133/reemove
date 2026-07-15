> **Production merge note:** Primary GitHub Actions workflows live at the repository root under `.github/workflows/` with `working-directory: reemove_app`. Package-local mirrors also exist under `reemove_app/.github/` for reference. Coverage gate reporting is non-blocking until global coverage meets `quality/quality_gates.json`.

> **Phase 16:** Additional workflows cover staging deploy, production deploy (signed tag + approval), Android/iOS release builds, and post-release smoke checks. See `docs/CI_CD_RELEASE_PIPELINE.md`.

# CI/CD Testing Guide

## Workflow files

- `.github/workflows/quality-gates.yml`: pull requests and main branch
- `.github/workflows/nightly-device-tests.yml`: scheduled broader testing

## Security principles

- Default GitHub token permissions are read-only.
- Jobs request only the permissions they need.
- Forked pull requests do not receive deployment secrets.
- Third-party actions should be reviewed and pinned to trusted immutable revisions before production rollout.
- Firebase credentials are used only for staging/device jobs that require them.
- Prefer short-lived workload identity/OIDC in Phase 16 rather than long-lived service-account keys.

## Required repository configuration

- Protected main branch
- Required quality workflow
- Review requirement for `.github/`, Firebase rules, functions, and security policy changes
- CODEOWNERS for security-sensitive paths
- Environments for staging and production with approvals
- Dependency update automation
- Secret scanning and push protection where available

## Artifacts

Upload test reports, coverage, screenshots, integration logs, and performance traces. Set reasonable retention and never upload raw secrets, private user content, or precise user location.

## Flaky failures

Do not automatically rerun until green and ignore the first failure. One diagnostic rerun is acceptable, but the job should preserve and report that the original run failed.
