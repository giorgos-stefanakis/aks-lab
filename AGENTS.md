# AGENTS.md

Instructions for coding agents in this repository. Claude Code reads this file directly.

## Purpose

A throwaway lab. It shows that a FastAPI service and an Azure Functions app can run on Kubernetes (kind and AKS),
with Azure as the control plane and Argo CD as the delivery mechanism. It is a prototype, not a product.

## Read order

1. [docs/SPEC.md](docs/SPEC.md): what we build and why, and the acceptance checks.
2. [docs/DECISIONS.md](docs/DECISIONS.md): prototype decisions. None of them is final.
3. [docs/PLAN.md](docs/PLAN.md): milestones and order.
4. [docs/TASKS.md](docs/TASKS.md): the work, with status.
5. [docs/LOG.md](docs/LOG.md): verified findings, newest last.

## Living docs

| File | Owner | Agent may |
|---|---|---|
| SPEC.md | Owner | Propose changes only |
| DECISIONS.md | Owner | Propose changes only |
| PLAN.md | Owner and agents | Refine inside the agreed scope |
| TASKS.md | Agents | Set status (`todo`, `doing`, `done`, `blocked`), add tasks |
| LOG.md | Agents | Append dated entries. Never edit old entries. |

- Set a task to `doing` when you start it and to `done` when its check passes.
- Log a fact when you verify it: versions, limits, surprises, things that failed.
- One fact lives in one place. Other files link to it.
- The repo is standalone. No company names, no paths outside this repo, no links to private documents.

## Guardrails

These rules are hard. A hook in `.claude/hooks/guard-bash.sh` enforces most of them for Claude Code.
Other agents follow them by hand.

**Azure**
- Every `az` call passes `--subscription <LAB_SUBSCRIPTION_ID>` with the literal ID from `.lab.env`.
  Never run `az login`, `az logout` or `az account set`.
- Never provision, change or delete Azure resources. The owner deploys, through `make` or CI.
- What-if comes before every deploy. `make infra-deploy` uses `--confirm-with-what-if`.
- Ask before any other `az` call, including read-only ones.
- Never print secret values: no `keyvault secret show`, `ad sp create-for-rbac`, `acr credential show`,
  `--show-secrets` or credential resets.

**Kubernetes**
- Every `kubectl` and `helm` call that reaches a cluster passes `--context` or `--kube-context`.
- On the kind cluster, agents may change state freely.
- On AKS, state changes go through git and Argo CD only. Never `apply`, `create`, `delete`, `patch`, `edit`,
  `scale` or `rollout` against AKS.

**GitHub and registries**
- Ask before `gh`, `git push`, `docker push`, `docker login`, `helm push` and any cluster-facing `helm` command.
- Never force-push.

**Scope**
- Add no component, Azure resource or dependency that SPEC.md does not list. Ask first.
- Check the licence of every new component. Allowed: MIT, Apache 2.0, BSD, LGPL, public domain.
  Forbidden: GPL, AGPL, MPL, SSPL, BSL.
- Pin every version. Never use `latest` tags or floating chart versions.
- Consume external Helm charts from upstream. Never vendor them.
- Never commit secrets, `.lab.env`, kubeconfig files or `.env` files.

## Conventions

- **Python:** 3.12 through pyenv (`.python-version`). Poetry with `package-mode = false` and an in-project `.venv`.
  Ruff for lint and format, Google docstrings, line length 140. pytest with pytest-asyncio, tests in `tests/unit`.
- **Make:** each component has a Makefile with `init`, `run`, `test`, `lint`. The root Makefile drives the lab.
- **Bicep:** Azure resources only. Incremental mode. One resource group.
- **GitOps:** Argo CD app-of-apps, one root app per cluster. Our charts come from ACR as OCI; values come from git.
- **Indentation:** 4 spaces, 2 for YAML and JSON, tabs in Makefiles.

## Authoring rules

### Prose
Tight, plain technical English (ASD-STE100 as a guide): short sentences, active voice, one idea each.
No mannered prose, filler, filler sections or emoji. Applies to comments, commits, PRs, docs and replies.

### Comments
The code is the source of truth. A comment never mirrors it. Comment only a why the code cannot show:
intent, a constraint, a workaround. One line where possible. No change narration, no commented-out code.
Public API docs where the language or repo expects them.

### Commits
- Only when I ask. Convention: commitlint, CONTRIBUTING, `git log`; else Conventional Commits.
- Split by feature, then by logical change if that helps review. Every commit builds.
- A subject line. A body of 1-3 lines only when the diff does not show the why.
- Your own commits from this task, not yet pushed or shown to me: fix them in place (amend, or fixup and
  autosquash over those commits only). Earlier commits: `git commit --fixup=<sha>`. I squash those.
- No attribution (`Co-Authored-By`, "Generated with …") in commits or PRs.

## Commands

Added as milestones land. See [docs/PLAN.md](docs/PLAN.md).
