# Checkpoints

Recovery checkpoints (append-only). If execution stops, resume from the latest.

## Checkpoint 000 — CI-A0 bootstrap
- **Completed boards:** none
- **Completed classes:** none
- **Completed subjects:** none
- **Downloaded files:** 0
- **Metadata generated:** 0
- **Reports generated:** yes (empty-state)
- **Pending work:** CI-A1 discovery + acquisition (networked run required)
- **Recovery instructions:** re-run scaffold_workspace.py + pm_bootstrap.py (idempotent), then pm_sync.py; state is reconstructed from the queues + indexes.
