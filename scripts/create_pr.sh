#!/usr/bin/env bash
set -euo pipefail

# Simple helper to commit current changes and open a PR.
# Usage:
#   ./scripts/create_pr.sh "commit message" "PR title" "PR body"
# Requirements:
#   - git on PATH (present in the dev container)
#   - Either the GitHub CLI (gh) installed, or environment variables:
#       GITHUB_TOKEN (a token with repo permissions)
#       REPO (owner/repo, e.g. user/repo)
#
# The script will:
#   - create a branch save-updates-<ts> if current branch is main or master
#   - stage all changes, commit with the provided message (or default)
#   - push the branch and open a PR against the repository default branch (or main)

COMMIT_MSG="${1:-Save updates}"
PR_TITLE="${2:-Save updates}"
PR_BODY="${3:-Automated PR created by scripts/create_pr.sh}"

# Determine current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# If on main or master, create a feature branch
if [[ "$CURRENT_BRANCH" == "main" || "$CURRENT_BRANCH" == "master" ]]; then
  TS=$(date +%s)
  BRANCH="save-updates-${TS}"
  git checkout -b "$BRANCH"
else
  BRANCH="$CURRENT_BRANCH"
fi

# Stage and commit
git add -A
if git diff --cached --quiet; then
  echo "No changes to commit."
else
  git commit -m "$COMMIT_MSG"
fi

# Push branch
git push --set-upstream origin "$BRANCH"

# Create PR: prefer gh CLI if available
if command -v gh >/dev/null 2>&1; then
  echo "Creating PR with gh..."
  # --web can be used to open the browser instead of creating; we create directly
  gh pr create --title "$PR_TITLE" --body "$PR_BODY" --head "$BRANCH" --base main || gh pr create --title "$PR_TITLE" --body "$PR_BODY" --head "$BRANCH"
  exit 0
fi

# Fallback: use GitHub API via curl
if [[ -z "${GITHUB_TOKEN:-}" || -z "${REPO:-}" ]]; then
  echo "Neither gh CLI found nor GITHUB_TOKEN/REPO provided. PR not created automatically."
  echo "You can create a PR manually with: git push && gh pr create OR use curl with GITHUB_TOKEN and REPO set."
  exit 0
fi

API_URL="https://api.github.com/repos/${REPO}/pulls"
DEFAULT_BASE="main"

# Try to create PR
JSON_PAYLOAD=$(printf '{"title":"%s","head":"%s","base":"%s","body":"%s"}' "$PR_TITLE" "$BRANCH" "$DEFAULT_BASE" "$PR_BODY")

resp=$(curl -s -o /dev/stderr -w "%{http_code}" -X POST "$API_URL" \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -d "$JSON_PAYLOAD" || true)

if [[ "$resp" == "201" || "$resp" == "200" ]]; then
  echo "Pull request created successfully."
else
  echo "Failed to create PR (HTTP status: $resp). Check GITHUB_TOKEN and REPO values."
fi
