# Open-Source Checklist for PupillometryApp

## Files Created
- [x] `.gitignore` - Comprehensive ignore rules
- [x] `.gitattributes` - Git LFS tracking for ML models
- [x] `GoogleService-Info.plist.example` - Template with placeholder credentials

## Before Your First Public Commit

Since secrets and test data are already in git history, you need to **remove them
from tracking** before pushing publicly. Run these commands in order:

### Step 1: Remove secrets from git tracking (keeps local files intact)
```bash
cd /Users/revathiprasad/Documents/GitHub/Pupl/PupillometryApp

# Remove GoogleService-Info.plist from git (keeps your local copy)
git rm --cached PupillometryApp/GoogleService-Info.plist

# Remove xcuserdata (personal IDE state)
git rm -r --cached "Pods/Pods.xcodeproj/xcuserdata/"
git rm -r --cached "PupillometryApp.xcodeproj/xcuserdata/"
git rm -r --cached "PupillometryApp.xcworkspace/xcuserdata/"

# Remove Firebase test session data
git rm -r --cached Firebase/

# Remove Pods (contributors will run pod install)
git rm -r --cached Pods/

# Remove .DS_Store files
find . -name ".DS_Store" -exec git rm --cached {} \; 2>/dev/null

# Remove .claude settings
git rm --cached .claude/settings.local.json
```

### Step 2: Commit the cleanup
```bash
git add .gitignore .gitattributes GoogleService-Info.plist.example
git commit -m "Prepare repo for open-sourcing: add .gitignore, remove secrets and test data"
```

### Step 3: Scrub secrets from git history (IMPORTANT)
Even after the above, the old commits still contain `GoogleService-Info.plist`
with your real API key. To fully remove it from history:

```bash
# Option A: Use git-filter-repo (recommended)
pip install git-filter-repo
git filter-repo --path PupillometryApp/GoogleService-Info.plist --invert-paths

# Option B: Use BFG Repo Cleaner
# Download from https://rtyley.github.io/bfg-repo-cleaner/
java -jar bfg.jar --delete-files GoogleService-Info.plist
git reflog expire --expire=now --all && git gc --prune=now --aggressive
```

### Step 4: Rotate your Firebase API key
Go to https://console.cloud.google.com/apis/credentials and regenerate your
API key (the one that was committed in `GoogleService-Info.plist`), since it was in git history.

### Step 5: Force push the clean history
```bash
git push origin main --force
```

## Optional: Add a LICENSE file
Common choices for research/medical apps:
- **MIT** - Permissive, anyone can use/modify
- **Apache 2.0** - Permissive with patent protection
- **GPL-3.0** - Copyleft, derivatives must also be open-source

## Optional: Add a README.md
See SETUP_INSTRUCTIONS.md for content to adapt into a proper README.
