#!/bin/zsh
set -euo pipefail

rm -rf "$HOME/Applications/Create Markdown.app"
rm -rf "$HOME/Library/Services/Создать .md.workflow"
/System/Library/CoreServices/pbs -update >/dev/null 2>&1 || true
killall Dock >/dev/null 2>&1 || true
echo "Создать .md удалена."
