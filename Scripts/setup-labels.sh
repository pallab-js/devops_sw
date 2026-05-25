#!/bin/bash
# Standalone script to create GitHub issue labels
# Run: bash Scripts/setup-labels.sh

set -euo pipefail

echo "Creating DevForge GitHub issue labels..."

LABELS=(
    "spec:pillar:#0075ca:Feature pillar spec"
    "spec:story:#cfd3d7:User story"
    "spec:task:#e4e669:Implementation task"
    "spec:bug:#d73a4a:Bug report"
    "spec:adr:#7057ff:Architecture Decision Record"
    "spec:done:#0e8a16:Spec implemented and verified"
    "ai:hallucination:#ff6b6b:AI-generated incorrect code detected"
    "ai:verified:#00b4d8:AI output human-verified"
)

for entry in "${LABELS[@]}"; do
    IFS=':' read -r name color desc <<< "$entry"
    echo "  Creating label: $name"
    gh label create "$name" --color "$color" --description "$desc" --force 2>/dev/null || \
        echo "    (skipped — may already exist)"
done

echo "Done. Run 'gh label list' to verify."
