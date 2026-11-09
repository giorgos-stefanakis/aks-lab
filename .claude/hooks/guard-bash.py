#!/usr/bin/env python3
"""PreToolUse guard for Bash commands. Enforces the guardrails in AGENTS.md.

Reads the hook JSON on stdin. Exits 2 to block, prints an "ask" decision to force a prompt,
or exits 0 silently to fall through to the normal permission rules. Fails closed on errors.
"""

from __future__ import annotations

import json
import os
import re
import shlex
import sys
from pathlib import Path

ALLOW, ASK, DENY = 0, 1, 2

SEPARATORS = {";", "&&", "||", "|", "|&", "&", "(", ")", "\n", ";;", "<(", ">("}
SHELLS = {"bash", "sh", "zsh", "dash"}
WRAPPERS = {"sudo", "env", "time", "command", "exec", "nohup", "nice", "xargs", "watch"}

AZ_READ_VERBS = {"show", "list", "what-if", "validate", "get-credentials", "wait", "query", "check-name", "get-versions"}
AZ_READ_PREFIXES = ("list-", "show-", "check-")
AZ_SECRET_PATTERNS = (
    "keyvault secret show",
    "keyvault secret download",
    "keyvault key download",
    "keyvault certificate download",
    "ad sp create-for-rbac",
    "acr credential",
    "credential reset",
    "account get-access-token",
    "storage account keys",
    "cognitiveservices account keys",
    "appconfig credential",
    "--show-secrets",
)
AZ_LOCAL = {("bicep", "build"), ("bicep", "build-params"), ("bicep", "lint"), ("bicep", "format"), ("bicep", "version")}
AZ_NO_SUBSCRIPTION = {("version",), ("account", "show"), ("account", "list"), ("acr", "login")}

KUBECTL_LOCAL = {"version", "kustomize", "help", "completion", "plugin"}
KUBECTL_CONFIG_READ = {"get-contexts", "current-context", "view"}
KUBECTL_MUTATING = {
    "apply", "create", "delete", "patch", "edit", "scale", "replace", "set", "label", "annotate", "rollout",
    "drain", "cordon", "uncordon", "taint", "run", "expose", "autoscale", "cp", "debug",
}  # fmt: skip

HELM_LOCAL = {"template", "lint", "package", "dependency", "dep", "show", "inspect", "create", "version", "env", "help", "search", "completion"}
HELM_REMOTE = {"push", "pull", "registry", "repo"}
HELM_CLUSTER_WRITE = {"install", "upgrade", "uninstall", "delete", "rollback", "test"}
HELM_CLUSTER_READ = {"list", "ls", "status", "get", "history"}

AZURE_HOSTS = re.compile(r"(management\.azure\.com|\.vault\.azure\.net|\.azconfig\.io|\.azurecr\.io|\.openai\.azure\.com|login\.microsoftonline\.com)")
SENSITIVE_WORDS = re.compile(r"\b(az|kubectl|helm|gh|argocd|docker|oras|skopeo|make)\b|git\s.*\bpush\b")


class Verdict:
    def __init__(self) -> None:
        self.level = ALLOW
        self.reasons: list[str] = []

    def raise_to(self, level: int, reason: str) -> None:
        if level > self.level:
            self.level = level
        if level > ALLOW:
            self.reasons.append(reason)


def lab_subscription() -> str:
    env_file = Path(os.environ.get("CLAUDE_PROJECT_DIR", ".")) / ".lab.env"
    if not env_file.is_file():
        return ""
    for line in env_file.read_text().splitlines():
        key, _, value = line.partition("=")
        if key.strip() == "LAB_SUBSCRIPTION_ID":
            return value.strip().strip("\"'")
    return ""


def tokenize(text: str) -> list[str]:
    lexer = shlex.shlex(text, posix=True, punctuation_chars="();<>|&\n")
    lexer.whitespace = " \t\r"
    lexer.whitespace_split = True
    lexer.commenters = ""
    return list(lexer)


def split_commands(tokens: list[str]) -> list[list[str]]:
    commands, current = [], []
    for token in tokens:
        if token in SEPARATORS or set(token) <= set("();<>|&\n"):
            if current:
                commands.append(current)
            current = []
        else:
            current.append(token.strip("`"))
    if current:
        commands.append(current)
    return commands


def strip_wrappers(cmd: list[str]) -> list[str]:
    while cmd:
        head = Path(cmd[0]).name
        if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*=.*", cmd[0]) or head in WRAPPERS:
            cmd = cmd[1:]
            while cmd and cmd[0].startswith("-"):
                cmd = cmd[1:]
        elif head == "timeout" and len(cmd) > 1:
            cmd = cmd[2:]
        else:
            break
    return cmd


def option_value(args: list[str], *names: str) -> str | None:
    for i, arg in enumerate(args):
        for name in names:
            if arg == name and i + 1 < len(args):
                return args[i + 1]
            if arg.startswith(name + "="):
                return arg.split("=", 1)[1]
    return None


def positionals(args: list[str], value_options: set[str] = frozenset()) -> list[str]:
    result, skip = [], False
    for arg in args:
        if skip:
            skip = False
        elif arg.startswith("-"):
            skip = arg in value_options
        else:
            result.append(arg)
    return result


def check_az(args: list[str], verdict: Verdict, lab_sub: str) -> None:
    joined = " ".join(args)
    groups = []
    for arg in args:
        if arg.startswith("-"):
            break
        groups.append(arg)
    if not groups or tuple(groups[:2]) in AZ_LOCAL:
        return
    if groups[0] in {"login", "logout"} or tuple(groups[:2]) in {("account", "set"), ("account", "clear")}:
        verdict.raise_to(DENY, f"az {' '.join(groups)}: the owner manages the Azure login and default subscription")
        return
    if any(pattern in joined for pattern in AZ_SECRET_PATTERNS) or ("get-credentials" in groups and "--admin" in args):
        verdict.raise_to(DENY, f"az {' '.join(groups)}: prints or creates secrets")
        return
    verb = groups[-1]
    is_read = verb in AZ_READ_VERBS or verb.startswith(AZ_READ_PREFIXES) or tuple(groups) in AZ_NO_SUBSCRIPTION
    if not is_read:
        verdict.raise_to(DENY, f"az {' '.join(groups)}: agents never change Azure resources; the owner deploys via make or CI")
        return
    if tuple(groups) not in AZ_NO_SUBSCRIPTION:
        if not lab_sub:
            verdict.raise_to(DENY, "az: LAB_SUBSCRIPTION_ID is missing from .lab.env")
            return
        if option_value(args, "--subscription") != lab_sub:
            verdict.raise_to(DENY, "az: pass --subscription with the literal LAB_SUBSCRIPTION_ID from .lab.env")
            return
    verdict.raise_to(ASK, f"az {' '.join(groups)}: Azure-facing call")


def check_kubectl(args: list[str], verdict: Verdict) -> None:
    pos = positionals(args, {"--context", "-n", "--namespace", "-l", "--selector", "-o", "--output", "-f", "--filename", "-c", "--container"})
    sub = pos[0] if pos else ""
    if sub in KUBECTL_LOCAL or not sub:
        return
    if sub == "config":
        if len(pos) > 1 and pos[1] in KUBECTL_CONFIG_READ:
            return
        verdict.raise_to(DENY, "kubectl config: do not change kubeconfig; pass --context instead")
        return
    context = option_value(args, "--context")
    if not context:
        verdict.raise_to(DENY, f"kubectl {sub}: pass --context explicitly")
        return
    if context.startswith("kind-"):
        return
    if sub in KUBECTL_MUTATING:
        verdict.raise_to(DENY, f"kubectl {sub} on {context}: AKS changes go through git and Argo CD")
        return
    verdict.raise_to(ASK, f"kubectl {sub} on {context}: remote cluster")


def check_helm(args: list[str], verdict: Verdict) -> None:
    pos = positionals(args, {"--kube-context", "-n", "--namespace", "-f", "--values", "--version", "-o", "--output", "--set", "--repo"})
    sub = pos[0] if pos else ""
    if sub in HELM_LOCAL or not sub:
        return
    if sub in HELM_REMOTE:
        verdict.raise_to(ASK, f"helm {sub}: registry-facing call")
        return
    context = option_value(args, "--kube-context")
    if not context:
        verdict.raise_to(DENY, f"helm {sub}: pass --kube-context explicitly")
        return
    if context.startswith("kind-"):
        return
    if sub in HELM_CLUSTER_WRITE:
        verdict.raise_to(DENY, f"helm {sub} on {context}: AKS changes go through git and Argo CD")
        return
    verdict.raise_to(ASK, f"helm {sub} on {context}: remote cluster")


def check_git(args: list[str], verdict: Verdict) -> None:
    pos = positionals(args, {"-C", "-c", "--git-dir", "--work-tree"})
    if not pos or pos[0] != "push":
        return
    if any(a.startswith(("--force", "--mirror", "--delete")) or a in {"-f", "-d"} for a in args) or any(p.startswith("+") for p in pos[1:]):
        verdict.raise_to(DENY, "git push: force, mirror and delete pushes are blocked")
        return
    verdict.raise_to(ASK, "git push: GitHub-facing call")


def check_make(args: list[str], verdict: Verdict) -> None:
    for target in positionals(args, {"-C", "-f", "--directory", "--file", "-j"}):
        if "=" in target:
            continue
        if re.fullmatch(r"(infra|aks)-.*(deploy|up|down|destroy|delete|stop|start)", target):
            verdict.raise_to(DENY, f"make {target}: provisions Azure resources; the owner runs it")
        elif re.match(r"(infra|aks|publish|ci)", target):
            verdict.raise_to(ASK, f"make {target}: Azure-facing target")


def check_command(cmd: list[str], verdict: Verdict, lab_sub: str, depth: int) -> None:
    cmd = strip_wrappers(cmd)
    if not cmd:
        return
    head, args = Path(cmd[0]).name, cmd[1:]
    if head in SHELLS and "-c" in args:
        idx = args.index("-c")
        if idx + 1 < len(args):
            check_text(args[idx + 1], verdict, lab_sub, depth + 1)
        return
    if head == "eval":
        check_text(" ".join(args), verdict, lab_sub, depth + 1)
        return
    checks = {
        "az": lambda: check_az(args, verdict, lab_sub),
        "kubectl": lambda: check_kubectl(args, verdict),
        "helm": lambda: check_helm(args, verdict),
        "git": lambda: check_git(args, verdict),
        "make": lambda: check_make(args, verdict),
    }
    if head in checks:
        checks[head]()
    elif head == "gh":
        if positionals(args)[:2] == ["repo", "delete"]:
            verdict.raise_to(DENY, "gh repo delete: blocked")
        else:
            verdict.raise_to(ASK, "gh: GitHub-facing call")
    elif head == "docker" and ({"push", "login"} & set(args) or "--push" in args):
        verdict.raise_to(ASK, "docker push/login: registry-facing call")
    elif head in {"argocd", "oras", "skopeo"}:
        verdict.raise_to(ASK, f"{head}: cluster- or registry-facing call")
    elif head in {"curl", "wget", "http", "https"} and AZURE_HOSTS.search(" ".join(args)):
        verdict.raise_to(ASK, f"{head}: direct call to an Azure endpoint")


def check_text(text: str, verdict: Verdict, lab_sub: str, depth: int = 0) -> None:
    if depth > 5:
        verdict.raise_to(ASK, "command nests too deep to check")
        return
    for inner in re.findall(r"\$\(([^()]*(?:\([^()]*\)[^()]*)*)\)|`([^`]*)`", text):
        check_text(inner[0] or inner[1], verdict, lab_sub, depth + 1)
    try:
        tokens = tokenize(text)
    except ValueError:
        if SENSITIVE_WORDS.search(text):
            verdict.raise_to(ASK, "command could not be parsed and mentions a guarded tool")
        return
    for cmd in split_commands(tokens):
        check_command(cmd, verdict, lab_sub, depth)


def main() -> int:
    payload = json.load(sys.stdin)
    command = (payload.get("tool_input") or {}).get("command") or ""
    verdict = Verdict()
    check_text(command, verdict, lab_subscription())
    reason = "; ".join(dict.fromkeys(verdict.reasons))
    if verdict.level == DENY:
        print(f"Blocked by guard-bash (see AGENTS.md, Guardrails): {reason}", file=sys.stderr)
        return 2
    if verdict.level == ASK:
        decision = {"hookEventName": "PreToolUse", "permissionDecision": "ask", "permissionDecisionReason": reason}
        print(json.dumps({"hookSpecificOutput": decision}))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:  # noqa: BLE001 - fail closed on any parser error
        print(f"guard-bash failed, blocking for safety: {exc}", file=sys.stderr)
        sys.exit(2)
