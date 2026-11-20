#!/bin/sh
set -eu
[ "$#" -eq 1 ] || { printf 'Usage: %s PROJECT_CONFIG\n' "$0" >&2; exit 2; }
template=$(dirname "$0")/install-archive.template.sh
[ -s "$1" ] || { printf 'Missing or empty project configuration: %s\n' "$1" >&2; exit 1; }
awk '
    FNR == NR { project = project $0 "\n"; next }
    /^# @INSTALL_PROJECT@$/ { printf "%s", project; next }
    { print }
' "$1" "$template"
