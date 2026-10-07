# lua → python helm values cache repro

Minimal git-backed Helm service that reproduces deployment-operator failures when a
service migrates from `helm.luaFile` to `helm.pythonFile` and the agent keeps a
stale service object while refreshing the manifest tarball.

Expected failure (unfixed agent):

```text
failed to read lua file values.lua: open /tmp/manifests.../values.lua: no such file or directory
```

A pod restart of the deployment-operator clears in-memory caches and "fixes" it.
With the operator fix (refresh service after manifest refetch), the python phase
should recover without a restart.

## Layout

| Path | Purpose |
|------|---------|
| `Chart.yaml` / `templates/` / `values.yaml` | Tiny chart; ConfigMap surfaces script output |
| `values.lua` | Phase 1 values script (deleted during migration) |
| `migrate/values.py` | Phase 2 script (copied to `values.py` by migrate script) |
| `manifests/01-service-lua.yaml` | ServiceDeployment using `luaFile` |
| `manifests/02-service-python.yaml` | Same service using `pythonFile` |
| `scripts/migrate-to-python.sh` | Commit that removes `values.lua` and adds `values.py` |

## Setup

This directory is already a standalone git repo on `main`.

```bash
cd /home/lukasz/GolandProjects/plural/demo-lua-python-cache
git remote add origin <your-remote-url>
git push -u origin main
```

Register that remote as a Plural `GitRepository`, then edit both manifests:
set `spec.cluster` and uncomment `repositoryRef` (or use `git.url`) for your environment.

## Reproduce

### 1. Deploy lua phase

```bash
kubectl apply -f manifests/01-service-lua.yaml
```

Wait until the service is healthy. In the target cluster:

```bash
kubectl -n lua-python-cache-demo get cm lua-python-cache-demo-values -o yaml
# engine: "lua"
# message: "rendered-by-lua"
```

### 2. Migrate git contents (delete lua file)

From this demo repo root:

```bash
./scripts/migrate-to-python.sh
git push
```

This changes the service digest and removes `values.lua` from the tarball while
the ServiceDeployment may still say `luaFile: values.lua` until step 3.

### 3. Switch the service to python

```bash
kubectl apply -f manifests/02-service-python.yaml
```

Also confirm in the Console UI/API that `helm.luaFile` is cleared (not only
`pythonFile` set). Omitted CRD fields are not always sent as GraphQL `null`.

### 4. Observe

**Unfixed agent (cache skew):** service errors with missing `values.lua` even
after step 3, until you restart the deployment-operator pod.

**Fixed agent:** next reconcile after manifest refetch reloads the service and
renders with `values.py`. ConfigMap becomes:

```yaml
engine: "python"
message: "rendered-by-python"
```

### Tips to make the race easier to hit

- Use a longer `--controller-cache-ttl` / service poll interval so a stale
  `ServiceDeploymentForAgent` can linger after the digest changes.
- Prefer watching operator logs while applying step 2 then step 3 a few seconds
  apart (git digest refresh vs service object refresh).
- If websockets immediately expire both caches on every update, the window is
  shorter; the sticky case is digest-driven tarball refresh + stale `luaFile`
  still in the local service cache.

## Cleanup

```bash
kubectl delete -f manifests/02-service-python.yaml --ignore-not-found
kubectl delete ns lua-python-cache-demo --ignore-not-found
```
