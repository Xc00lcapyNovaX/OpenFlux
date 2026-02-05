#!/bin/bash
cd "$(dirname "$0")"

# Clean up rebase state
rm -rf .git/rebase-merge .git/.COMMIT_EDITMSG.swp

# Reset HEAD to main
echo 'ref: refs/heads/main' > .git/HEAD

# Force push to GitHub (will overwrite remote)
git push -u --force origin main 2>&1

echo "Push complete!"
