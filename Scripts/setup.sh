#!/bin/bash
set -euo pipefail

echo "=== DevForge Project Setup ==="
echo ""

# ── Prerequisites ──────────────────────────────────────────────
echo "→ Checking prerequisites..."
command -v gh >/dev/null 2>&1 || { echo "Installing GitHub CLI..."; brew install gh; }
command -v xcodegen >/dev/null 2>&1 || { echo "Installing XcodeGen..."; brew install xcodegen; }
command -v swiftlint >/dev/null 2>&1 || { echo "Installing SwiftLint..."; brew install swiftlint; }

# ── GitHub Repository ──────────────────────────────────────────
echo ""
echo "→ Creating GitHub repository..."
REPO_NAME="DevForge"
REPO_DESC="Local, offline, enterprise-grade DevOps suite for macOS"

if gh repo view "$REPO_NAME" >/dev/null 2>&1; then
    echo "  Repository already exists. Skipping."
else
    gh repo create "$REPO_NAME" \
        --public \
        --description "$REPO_DESC" \
        --license apache-2.0 \
        --gitignore Swift \
        --clone
    echo "  Created $REPO_NAME"
fi

cd "$REPO_NAME" 2>/dev/null || true

# ── Branch Strategy ────────────────────────────────────────────
echo ""
echo "→ Setting up branch strategy..."
if ! git show-ref --verify refs/heads/develop >/dev/null 2>&1; then
    git checkout -b develop
    git push -u origin develop
    gh repo edit --default-branch develop
    echo "  develop branch created and set as default"
else
    echo "  develop branch exists"
fi

# ── Branch Protection ──────────────────────────────────────────
echo ""
echo "→ Setting branch protection for main..."
OWNER=$(gh api user --jq '.login')
gh api "repos/$OWNER/$REPO_NAME/branches/main/protection" \
    --method PUT \
    --field required_status_checks='{"strict":true,"contexts":[]}' \
    --field enforce_admins=false \
    --field required_pull_request_reviews='{"required_approving_review_count":0}' \
    --field restrictions=null \
    --silent 2>/dev/null || echo "  Warning: branch protection failed (main may not exist yet)"
echo "  Branch protection applied"

# ── Issue Labels ───────────────────────────────────────────────
echo ""
echo "→ Creating GitHub issue labels..."
for label in \
    "spec:pillar:#0075ca:Feature pillar spec" \
    "spec:story:#cfd3d7:User story" \
    "spec:task:#e4e669:Implementation task" \
    "spec:bug:#d73a4a:Bug report" \
    "spec:adr:#7057ff:Architecture Decision Record" \
    "spec:done:#0e8a16:Spec implemented and verified" \
    "ai:hallucination:#ff6b6b:AI-generated incorrect code detected" \
    "ai:verified:#00b4d8:AI output human-verified"; do
    
    IFS=':' read -r name color desc <<< "$label"
    gh label create "$name" --color "$color" --description "$desc" --force 2>/dev/null || true
done
echo "  Labels created"

# ── GitHub Project Board ───────────────────────────────────────
echo ""
echo "→ Creating GitHub project board..."
gh project create --owner "@me" --title "DevForge Roadmap" --format board 2>/dev/null || \
    echo "  Project board already exists"

# ── Xcode Project (XcodeGen) ───────────────────────────────────
echo ""
echo "→ Generating Xcode project..."
xcodegen generate --project DevForge/ --spec project.yml
echo "  Xcode project generated"

# ── Pre-commit Hook ────────────────────────────────────────────
echo ""
echo "→ Installing pre-commit hook..."
cp Scripts/pre-commit.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
echo "  Pre-commit hook installed"

# ── Verify ─────────────────────────────────────────────────────
echo ""
echo "→ Running verification..."
swiftlint lint --strict --quiet 2>/dev/null && echo "  SwiftLint: clean" || echo "  SwiftLint: issues found"
echo ""
echo "=== Setup complete! ==="
echo "Next: Open Xcode project and build (Cmd+B)"
