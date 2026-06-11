# Project Type — Desktop (app)

> Architectural concerns for a desktop app. Layered on top of the stack rules.

## Process & integration
- **Separate UI from privileged work.** Keep the rendering/UI layer thin; run file-system, network, and OS calls in a controlled layer with the narrowest privileges needed.
- **Single-instance where it matters.** Decide and enforce whether a second launch focuses the existing window or opens a new one; coordinate shared resources (files, ports, locks).
- **Integrate natively.** Honor platform menus, shortcuts, notifications, and window/state conventions per OS rather than one-size-fits-all.

## Data & safety
- **Write to the OS-designated app data/config dirs**, not next to the binary; never assume the install dir is writable.
- **Make file writes crash-safe** (write-temp-then-rename) so a crash mid-save can't corrupt user data; keep backups for destructive edits.
- **Store secrets in the OS credential store**, not plaintext config.

## Distribution
- **Ship signed builds**; never commit signing keys or certificates.
- **Auto-update must be verifiable** (signature-checked) and recoverable on a failed update.
