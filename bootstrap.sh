#!/usr/bin/env bash

set -euf -o pipefail

# --- Argument Parsing ---
MODE=""
# A simple loop to grab --mode
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      if [[ -n "$2" && ! "$2" =~ ^-- ]]; then
        MODE="$2"
        shift 2
      else
        echo "Error: --mode requires a value." >&2
        exit 1
      fi
      ;;
    *)
      echo "Error: Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$( cd "$( dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd )"

chmod 754 -Rc "$SCRIPT_DIR/scripts/"