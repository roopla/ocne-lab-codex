# CVU container-host validation results

Both workers passed the CVU Kubernetes container-host component on **10 October 2026**, with exit code 0. This is host prerequisite acceptance; image/gold-home and running-database acceptance remain separate.

| Item | Recorded value |
|---|---|
| Source file | ISO/cvupack_linux_ol8_x86_64.zip, supplied by user |
| Size | 133049247 bytes |
| SHA256 | 23da73fed4b9403f933a5bbb8e75e9b6931ed5fd33fd1dbfc6503227de70bdc8 |
| Archive validation | All317 ZIP members passed CRC; archive paths checked; worker copies matched SHA256 |
| Version | Standalone 23.26.3.0.0, build 090726x8664 |
| README platform header | Linux x86_64, OL8/OL9/RHEL8/RHEL9, July 2026 |
| Guest installation | /scratch/tools/cvu-23.26.3, on both workers |
| Execution account | labadmin; no root bypass and no automatic fixups |
| Worker1 report directory | /home/labadmin/cvu-reports/20261010T130103Z |
| Worker2 report directory | /home/labadmin/cvu-reports/20261010T130115Z |
| Host raw output | logs/ssh-ocne-w1-Verify-RAC-CVU-20261010-090103.txt and logs/ssh-ocne-w2-Verify-RAC-CVU-20261010-090114.txt |

The hash is a local fingerprint. Oracle's public landing page displayed a different archive size/hash; no matching publisher-checksum verification is claimed. The supplied package's actual README/version and successful execution are recorded instead of assuming its version from the filename.

## Checks that passed on each worker

Physical/available memory, zero swap, run level, x86_64 architecture, UEKR7 kernel version, configured/runtime file-max and socket buffer sysctls, aio-max-nr, panic settings, real-time CPU scheduling limit, TSC clock source, /dev/shm filesystem, available filesystem space and HugePages existence all passed. CVU reported current panic_on_oops1 and kernel.panic10, with configured values undefined; these were existing runtime values and were not changed to force a pass.

CVU's host-memory minimum for this component is 8GiB. Passing it does not certify the constrained22GiB worker or16GiB+2 GiB pod for an Oracle workload. Separate live diagnostics verified the planned pod resources can schedule, HugePages mounts and unsafe sysctls work, and both private networks and Kubernetes DNS pass after worker reboots.

## Equivalent Bash commands

From Windows Git Bash at the project root, using the configured aliases:

```bash
sha256sum ISO/cvupack_linux_ol8_x86_64.zip
# First prepare /scratch/tools/cvu-23.26.3 on each worker as described below.
scp ISO/cvupack_linux_ol8_x86_64.zip ocne-w1:/scratch/tools/cvu-23.26.3/
scp ISO/cvupack_linux_ol8_x86_64.zip ocne-w2:/scratch/tools/cvu-23.26.3/
```

On each worker for a **new** CVU installation, inspect /scratch's UUID first, then create the directory as root. The existing installation must not be overwritten blindly:

```bash
findmnt -M /scratch -o SOURCE,UUID,FSTYPE,TARGET
sudo install -d -m 0755 /scratch/tools
sudo install -d -m 0755 -o labadmin -g labadmin /scratch/tools/cvu-23.26.3
```

After copying, run as labadmin:

```bash
set -euo pipefail
cd /scratch/tools/cvu-23.26.3
printf '%s  %s\n' 23da73fed4b9403f933a5bbb8e75e9b6931ed5fd33fd1dbfc6503227de70bdc8 cvupack_linux_ol8_x86_64.zip | sha256sum -c -
unzip -tq cvupack_linux_ol8_x86_64.zip
# Extraction is needed only for a new installation.
test ! -e bin
unzip -q -n cvupack_linux_ol8_x86_64.zip
./bin/cluvfy -version
./bin/cluvfy comp -help
report="$HOME/cvu-reports/$(date -u +%Y%m%dT%H%M%SZ)"
install -d -m 0700 "$report"
./bin/cluvfy comp containerhost -type k8 -verbose -text -savedir "$report"
```

For repeat validation use only the last three commands and the installed tool; do not repeat the new-installation guard/extraction. Check the exit code and complete report, not merely that a report file exists. This component has no -n or -r option, so it runs locally on each worker without a release switch. Keep no -fixup/-fixupnoexec in the acceptance command.

Automation equivalents: [Prepare-RAC-CVU-Staging.sh](../scripts/Prepare-RAC-CVU-Staging.sh), [Inspect-RAC-CVU.sh](../scripts/Inspect-RAC-CVU.sh), [Verify-RAC-CVU.sh](../scripts/Verify-RAC-CVU.sh). Oracle sources: [CVU download page](https://www.oracle.com/database/technologies/cvu-downloads.html), Oracle Support patch30839369 and [Doc2731675.1](https://support.oracle.com/rs?type=doc&id=2731675.1); the package's readme.txt and cluvfy comp -help determined the executed syntax. These are diagnostic commands, not a26ai installation workflow.
