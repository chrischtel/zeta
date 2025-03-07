#!/bin/bash
# Usage: ./release.sh [major|minor|patch]

set -e

TYPE=${1:-patch}
CURRENT_VERSION=$(grep 'VERSION = ' build.zig | head -1 | cut -d'"' -f2)

MAJOR=$(echo $CURRENT_VERSION | cut -d. -f1)
MINOR=$(echo $CURRENT_VERSION | cut -d. -f2)
PATCH=$(echo $CURRENT_VERSION | cut -d. -f3)

case $TYPE in
  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    ;;
  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    ;;
  patch)
    PATCH=$((PATCH + 1))
    ;;
  *)
    echo "Invalid version type. Use major, minor, or patch."
    exit 1
    ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH"
echo "Bumping version: $CURRENT_VERSION → $NEW_VERSION"

# Update version in build.zig
sed -i "s/VERSION = \"$CURRENT_VERSION\"/VERSION = \"$NEW_VERSION\"/" build.zig

# Generate changelog entries
git log --pretty=format:"- %s" $(git describe --tags --abbrev=0)..HEAD > CHANGELOG.new
echo -e "# Zeta $NEW_VERSION\n\n$(cat CHANGELOG.new)\n\n$(cat CHANGELOG.md)" > CHANGELOG.md
rm CHANGELOG.new

# Commit changes
git add build.zig CHANGELOG.md
git commit -m "chore: bump version to $NEW_VERSION"
git tag -a "v$NEW_VERSION" -m "Release v$NEW_VERSION"

echo "Version bumped to $NEW_VERSION and tagged."
echo "Run 'git push && git push --tags' to publish the new version."
