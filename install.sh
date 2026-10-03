#!/bin/bash
set -euo pipefail
command -v node >/dev/null || { echo "Oma Prism requires Node.js (node)." >&2; exit 1; }
project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
exec node "$project/tools/install.mjs" "$@"
