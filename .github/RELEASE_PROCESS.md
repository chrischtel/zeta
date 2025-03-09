# Zeta Release Process Guide

This document explains the different release paths available in our project.

## Standard Release Process

1. **Feature Development**:
   - Create feature branches from develop: `gh workflow run Feature-Branch-Management -f action=create -f featureName="your-feature"`
   - Develop and test your feature
   - When ready: `gh workflow run Feature-Branch-Management -f action=ready-for-review -f featureName="your-feature"`
   - Review and merge via PR to develop

2. **Release Candidate Creation**:
   - When ready for release: `gh workflow run Create-Release-Candidate -f versionType=minor`
   - Test the RC thoroughly
   - Fix any issues directly in the release branch

3. **Release Finalization**:
   - When RC is stable: `gh workflow run Finalize-Release -f releaseBranch=release/x.y.z`
   - This promotes the RC to a full release, merges to main, and creates all assets

## Hotfix Process

1. **Create Hotfix**:
   - `gh workflow run Hotfix-Process -f baseBranch=main -f hotfixName="fix-critical-issue"`
   - Implement and test the fix in the created branch

2. **Release Hotfix**:
   - `gh workflow run Release-Hotfix -f hotfixBranch=hotfix/fix-critical-issue -f targetBranch=main`
   - This creates a release and merges changes to both main and develop

## Quick One-Click Release

For simpler projects or minor patches:

- **Regular Release**: `gh workflow run one-click-release -f releaseType=patch`
- **Pre-release**: `gh workflow run one-click-release -f releaseType=patch -f preReleaseType=alpha`
- **Promote Pre-release**: `gh workflow run one-click-release -f promoteToProd=true`
