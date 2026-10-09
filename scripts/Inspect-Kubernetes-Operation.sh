set -euo pipefail
[[ $(hostname -s) == ocne-op && $(id -un) == labadmin ]]
olcnectl operation logs --operation-id 1814585352938241022 | tail -n 35 | sed -E 's/[a-z0-9]{6}\.[a-z0-9]{16}/[redacted-bootstrap-token]/g; s/(--token|--certificate-key|--password)[= ]+[^ ]+/\1 [redacted]/g'