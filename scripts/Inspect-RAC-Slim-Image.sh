#!/bin/bash
# Read image files without starting its entrypoint or installing either home.
set -euo pipefail
[[ $(id -u) == 0 ]]
image=docker.io/roopla/oracle-rac@sha256:d4aa7fecb15b4f62caed83a0f445a275cc5bd8fbd1b01c7ac6216037b656566d
crictl inspecti "$image" >/dev/null
mountpoint=$(podman image mount "$image")
trap 'podman image unmount "$image" >/dev/null' EXIT
cat "$mountpoint/etc/os-release"
grep -E '^(oracle|grid):' "$mountpoint/etc/passwd"
grep -E '^(oinstall|dba|asmadmin|asmdba|asmoper):' "$mountpoint/etc/group"
ls -l "$mountpoint/usr/sbin/init"
find "$mountpoint/opt" -maxdepth 8 -type f -name '*.sh' -printf '/opt/%P\n' | sort
find "$mountpoint/usr/bin" -maxdepth 1 -type f -iname '*rac*' -printf '/usr/bin/%f\n'
podman image inspect "$image" --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -E '^(INITSH|ORACLE_HOME|GRID_HOME|SCRIPT_DIR|SCRIPTS_DIR|ORACLE_BASE)='
ls -l "$mountpoint/usr/bin/initsh"
find "$mountpoint/etc/systemd/system" -type l -lname '*oracle*' -printf '%P -> %l\n'
find "$mountpoint/opt/scripts/startup" -maxdepth 4 -type f -printf '%P\n' | sort
