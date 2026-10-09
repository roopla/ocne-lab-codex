# Instructions for Codex working in this lab

Read README.md, config/lab.psd1, and docs/OCNE-1.9-OL9-Setup-Guide.md first.

## Scope and source requirements

- Build the user's OCNE 1.9 home lab, using the original Oracle Installation guide and its linked Kubernetes continuation.
- Windows/VirtualBox orchestration and host provisioning inputs are our local implementation. Identify them as such.
- Linux/OCNE steps must follow the cited Oracle sections. Do not replace the full procedure with Quick Install, `olcnectl provision`, standalone kubeadm, or an OCNE 2.x workflow.
- Implement the user-requested additional 100 GiB NFS disk on the operator using guide Part D and the cited Oracle Linux 9 NFS/XFS/filesystem manuals. This is separate from OCNE prerequisites. Keep worker RAM at 22 GiB each.
- Preserve Oracle Linux 9 / UEK R7 and the source's eligible-update policy; inspect the actual ISO/kernel. Do not assume a newer kernel or arbitrary minor version meets the table.
- The user specifically requested RAM 4/8/22/22 GiB for operator/control-plane/worker1/worker2. OP/CP are below Oracle minimums. Disclose observed resource failures; do not claim this configuration is validated.
- Do not add blanket passwordless sudo, disable SELinux, or replace Oracle's firewall rules without a concrete source and explanation.

## Working locally

- Start with scripts/00-Inspect-Host.ps1 and inspect existing VM/network state before changes.
- The project root is the directory containing this file. Keep ISO files under ISO/, VM files under vms/, raw local output under logs/, and any host-side secrets under private/.
- Never delete or recreate an existing VM/network to resolve a naming conflict. Diagnose partial runs and continue only necessary steps.
- Create fresh VMs using the checked-in scripts. Do not also run the duplicate inline creation blocks in the guide.
- The configuration file supplies non-secret values for Windows scripts. It does not dynamically rewrite the guide or modify a live cluster; keep source substitutions consistent if changing names/IPs.
- Complete OS installation before running script 03. The package has no unattended OS installer. If automating installation, first identify the ISO and document the generated installation method without inventing OCNE requirements.
- Follow permitted local execution boundaries. Handle administrator/credential prompts through the user-facing mechanism when necessary.
- Run script 05 only after OS installation, with the operator powered off. Before formatting, inspect device identity, signatures, partitions, and mounts; never guess /dev/sdb or reformat an existing disk. Preserve existing exports and fstab entries.
- Verify the NFS data filesystem is mounted before exporting it. Match labadmin numeric UID/GID across nodes, retain root squashing and SELinux, and verify real read/write access from all nodes. Do not add PV/PVC resources or a provisioner without a separate sourced task.
- Use SSH for guest-side execution. Linux OS state and platform certificates reside in the guests at Oracle's paths; a single Windows project folder does not relocate them.
- Keep passwords, private keys, CA keys, kubeconfigs, and raw credentials out of tracked files and tool output.

## Documentation and Git

- Record actual progress and sanitized findings in docs/RUN-LOG.md. Never mark unexecuted steps complete.
- Preserve the linked sources, Oracle attribution, and license in the guide.
- Check git diff and staged filenames before committing; .gitignore is not a credential scanner.
- Do not push to an external repository until the user identifies the destination and authorizes the push.
- The cloning build and ordered-restart acceptance were executed on Windows and recorded in docs/CLONING-RUN-LOG.md on 2026-10-01. Preparation-time statements are historical. Continue to verify PowerShell parsing before execution, inspect current state, and do not rerun one-time creation/identity/formatting on the completed lab.
