---
name: tentacular
version: "0.1.0"
description: |
  Use this skill when building, deploying, or managing Tentacular workflows — a security-first
  DAG workflow runner for Kubernetes. Covers: initial cluster environment profiling, workflow
  design guided by cluster capabilities, tntc CLI commands for the full workflow lifecycle
  (init, validate, dev, build, deploy, run, status, undeploy), and drift-triggered re-profiling.
  Always load the environment profile before designing tentacles for a target cluster.
---

# Tentacular Skill

## Overview

Tentacular runs agentic DAG workflows in Kubernetes with gVisor sandboxing, NetworkPolicy
egress contracts, and secret isolation. The `tntc` CLI manages the full lifecycle.

**Before building any tentacle for a target environment, load its cluster profile.**
The profile tells you what's available: CNI, CSI, RuntimeClasses, extensions (Istio, etc.),
namespace constraints, and explicit agent guidance strings.

---

## Initial Setup

When a user first configures tentacular or adds a new environment:

```bash
# 1. Write project config (and auto-profile all environments)
tntc configure --project

# This will:
# - Write .tentacular/config.yaml
# - Connect to each environment
# - Save .tentacular/envprofiles/<env>.md and <env>.json
```

If `configure` doesn't reach all clusters (e.g., VPN not active), profile manually:

```bash
tntc cluster profile --env prod --save
tntc cluster profile --all --save        # all environments at once
```

---

## Before Building a Tentacle — Load the Profile

**Every time** you design a new workflow for environment `<env>`:

1. Check if `.tentacular/envprofiles/<env>.md` exists.
2. If it exists and `generatedAt` is within 7 days → read it and follow the **Agent Guidance** section.
3. If it's missing or stale → run `tntc cluster profile --env <env> --save` first, then read it.

```bash
# Check profile freshness
cat .tentacular/envprofiles/prod.md | head -3

# Rebuild if needed
tntc cluster profile --env prod --save --force
```

### Using the Profile to Design Tentacles

The **Agent Guidance** section at the bottom of each profile is the primary directive.
Common guidance strings and what they mean for tentacle design:

| Guidance | Action |
|----------|--------|
| `Use runtime_class: gvisor` | Set `runtime_class: gvisor` in workflow.yaml |
| `gVisor not available` | Omit `runtime_class` or set to `""` |
| `kind cluster detected` | Set `runtime_class: ""`, use `imagePullPolicy: IfNotPresent` |
| `Istio detected: NetworkPolicy egress must include namespaceSelector for istio-system` | Add `namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: istio-system}}` to all egress rules |
| `Namespace enforces restricted PodSecurity` | Containers must run as non-root, `allowPrivilegeEscalation: false`, read-only root filesystem |
| `RWX storage available via <name>` | Use that StorageClass for shared volume mounts across replicas |
| `No RWX-capable StorageClass` | Each pod needs its own volume; don't share PVCs across replicas |
| `ResourceQuota active` | Set resource requests and limits within quota bounds |
| `cert-manager available` | TLS can be provisioned automatically for fetch/synthesize nodes |

---

## Workflow Design Lifecycle

```bash
# 1. Scaffold
tntc init my-workflow

# 2. Write nodes (TypeScript)
# nodes/*.ts — export default async function run(ctx, input)

# 3. Validate DAG
tntc validate

# 4. Test locally (no cluster needed)
tntc test

# 5. Build container
tntc build --push

# 6. Deploy to environment
tntc deploy --env prod

# 7. Check status
tntc status my-workflow

# 8. Trigger
tntc run my-workflow

# 9. View logs
tntc logs my-workflow -f
```

---

## Drift Detection and Re-Profiling

Re-profile when the agent observes any of these signals:

```bash
tntc cluster profile --env <name> --save --force
```

**Trigger signals:**

- Deploy fails with `unknown RuntimeClass` → profile to find what's available now
- NetworkPolicy rejects traffic the profile said was allowed → CNI or policy changed
- PVC fails to bind → StorageClass or CSI driver changed
- `tntc cluster check` passes but deploy has unexpected resource errors → quota/LR changed
- Profile `generatedAt` > 7 days old
- K8s version in profile differs from what `tntc cluster check` reports
- User mentions cluster upgrade, new add-on, or infrastructure change
- A new extension (Istio, cert-manager, etc.) was recently installed

After re-profiling, re-read the updated guidance section before proceeding.

---

## Environment Configuration

Environments are defined in `.tentacular/config.yaml`:

```yaml
environments:
  dev:
    context: kind-local        # kubeconfig context
    namespace: dev-workflows
    runtime_class: ""          # no gVisor in kind

  prod:
    kubeconfig: ~/secrets/prod.kubeconfig
    context: prod-admin
    namespace: tentacular
    runtime_class: gvisor
```

Use `--env <name>` with any command:
```bash
tntc deploy --env prod
tntc cluster check --env staging
tntc cluster profile --env prod --save
```

---

## tntc Command Reference Summary

| Command | Description |
|---------|-------------|
| `tntc init <name>` | Scaffold new workflow |
| `tntc validate [dir]` | Validate workflow.yaml |
| `tntc dev [dir]` | Local dev server, hot-reload |
| `tntc test [dir]` | Run tests against fixtures |
| `tntc build [dir]` | Build container image |
| `tntc deploy [dir] --env <env>` | Deploy to cluster |
| `tntc status <name>` | Check deployment readiness |
| `tntc run <name>` | Trigger workflow, get result |
| `tntc logs <name> [-f]` | View/stream pod logs |
| `tntc list` | List all deployed workflows |
| `tntc undeploy <name>` | Remove workflow from cluster |
| `tntc cluster check [--env <env>]` | Preflight readiness check |
| `tntc cluster profile [--env <env>] [--save]` | Capability snapshot for workflow design |
| `tntc configure` | Write config + auto-profile all environments |
| `tntc secrets check` | Verify secrets provisioning |

---

## Node Contract

Each node is a TypeScript file:

```typescript
import type { Context } from "tentacular";

export default async function run(ctx: Context, input: unknown): Promise<unknown> {
  ctx.log.info("node running");
  // ctx.secrets.myservice.token — injected from K8s Secret
  // ctx.config.key              — from workflow config block
  return { result: "done" };
}
```

Nodes must be deterministic, idempotent where possible, and must not assume
shared filesystem state between runs unless explicitly using a shared PVC.

---

## Security Defaults

- **gVisor**: Use `runtime_class: gvisor` unless profile says it's unavailable
- **NetworkPolicy**: Tentacular generates egress contracts automatically from node contracts; review them against the CNI's capabilities in the profile
- **Secrets**: Never in environment variables — always volume mounts
- **Non-root**: Always run containers as non-root (required for restricted PSA namespaces)
