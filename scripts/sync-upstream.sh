#!/usr/bin/env bash
set -e

FEATURE_BRANCH="${1:-linux-cross-platform}"

echo "==> Checking repository safety state..."

# 1. Check if a rebase is currently in progress
GIT_DIR="$(git rev-parse --git-path .)"
if [ -d "$GIT_DIR/rebase-merge" ] || [ -d "$GIT_DIR/rebase-apply" ]; then
    echo "ERROR: A Git rebase is already in progress!"
    echo "  -> Complete it:  git add <files> && git rebase --continue"
    echo "  -> Or abort it: git rebase --abort"
    exit 1
fi

# 2. Check if a merge is currently in progress
if [ -f "$GIT_DIR/MERGE_HEAD" ]; then
    echo "ERROR: A Git merge is currently in progress!"
    echo "  -> Resolve conflicts and commit, or run: git merge --abort"
    exit 1
fi

# 3. Check for modified or staged tracked changes
if [ -n "$(git status --porcelain -uno)" ]; then
    echo "ERROR: You have modified or staged tracked files. Please commit or stash them first."
    exit 1
fi

echo "==> Fetching latest changes from upstream..."
git fetch upstream

UPSTREAM_CHANGES=$(git log main..upstream/main --oneline)

# Check if main is already an ancestor of the feature branch
if git merge-base --is-ancestor main "${FEATURE_BRANCH}"; then
    MAIN_IN_FEATURE=true
else
    MAIN_IN_FEATURE=false
fi

# Exit early if upstream has no changes AND main is already in feature branch
if [ -z "$UPSTREAM_CHANGES" ] && [ "$MAIN_IN_FEATURE" = true ]; then
    echo "==> Everything is already up to date! No rebasing needed."
    exit 0
fi

if [ -n "$UPSTREAM_CHANGES" ]; then
    echo "==> New upstream commits found:"
    echo "$UPSTREAM_CHANGES"
fi

echo "==> Switching to main..."
git checkout main

echo ""
echo "========================================================================"
echo "==> Rebasing 'main' onto 'upstream/main'..."
echo "    IF THIS FAILS WITH CONFLICTS:"
echo "      1. Resolve conflicts in your editor."
echo "      2. Stage resolved files: git add <file>"
echo "      3. Continue:            git rebase --continue"
echo "      4. Restart script:      ./scripts/sync-upstream.sh"
echo "    (To cancel at any time, run: git rebase --abort)"
echo "========================================================================"
echo ""

git rebase upstream/main

echo "==> Switching to ${FEATURE_BRANCH}..."
git checkout "${FEATURE_BRANCH}"

echo ""
echo "========================================================================"
echo "==> Rebasing '${FEATURE_BRANCH}' onto 'main'..."
echo "    IF THIS FAILS WITH CONFLICTS:"
echo "      1. Resolve conflicts in your editor."
echo "      2. Stage resolved files: git add <file>"
echo "      3. Continue:            git rebase --continue"
echo "      4. Restart script:      ./scripts/sync-upstream.sh"
echo "    (To cancel at any time, run: git rebase --abort)"
echo "========================================================================"
echo ""

git rebase main

echo ""
echo "==> Local rebase complete! Your local branches are updated."
echo "==> When you are ready to update GitHub, run:"
echo "      git checkout main && git push origin main --force-with-lease"
echo "      git checkout ${FEATURE_BRANCH} && git push origin ${FEATURE_BRANCH} --force-with-lease"