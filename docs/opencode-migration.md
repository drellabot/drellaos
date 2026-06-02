# DrellaOS: OpenCode Migration Notes

## Current State

DrellaOS does not install or directly reference Claude Code. The OS image:

1. Installs the orchestrator from `github.com/drellabot/orchestrator`
2. The orchestrator provisions sandboxes (VMs or containers) for each task
3. Claude Code is installed **inside each sandbox** by the orchestrator, not in the OS image

Therefore, the primary migration work lives in the orchestrator repository
(see [orchestrator PR](https://github.com/drellabot/orchestrator/pull/65)).

## What Could Change in DrellaOS

### Option A: No Changes (Recommended Initially)

Since the orchestrator handles agent installation in sandboxes, DrellaOS needs
no changes for the migration. The orchestrator's agent backend abstraction
(see orchestrator PR) handles switching between Claude Code and OpenCode.

### Option B: Pre-install OpenCode for Interactive Use

If operators want to use OpenCode interactively on the DrellaOS host (outside
of orchestrator-managed sandboxes), OpenCode could be pre-installed:

```dockerfile
# In Containerfile, after existing package installs:
RUN curl -fsSL https://opencode.ai/install | bash
```

This would add `~/.opencode/bin/opencode` to the image. However, since
DrellaOS is a server image running automated workloads, interactive use is
uncommon and this is likely unnecessary.

### Option C: Install OpenCode via drella-update-orchestrator

The `drella-update-orchestrator` script could be extended to also install
OpenCode alongside gjoll:

```bash
# In usr/libexec/drella-update-orchestrator:
echo "Installing opencode"
curl -fsSL https://opencode.ai/install | bash
```

This keeps OpenCode up-to-date on the host, which could be useful if the
orchestrator needs the `opencode` binary on the host (e.g., for podman
sandboxes where the binary is volume-mounted rather than installed per-container).

## Dependency on Orchestrator

The migration sequence should be:

1. **orchestrator**: Merge agent backend abstraction (PR #65)
2. **orchestrator**: Switch default backend to OpenCode (after testing)
3. **gjoll**: Use OpenCode examples for new sandbox environments
4. **drellaos**: Update only if host-level OpenCode is needed (Option B or C)

No DrellaOS changes are blocked on or blocking the other repositories.
