# release.ps1 - Version bumping for Zeta project
# Usage: .\release.ps1 [major|minor|patch]

param(
    [Parameter(Position = 0)]
    [string]$VersionType = "patch"
)

# Validate version type
if ($VersionType -notin @("major", "minor", "patch")) {
    Write-Error "Invalid version type. Use major, minor, or patch."
    exit 1
}

# Extract current version from build.zig
$versionPattern = 'const VERSION = "([\d\.]+)"'
$buildContent = Get-Content -Path "build.zig" -Raw
$currentVersion = [regex]::Match($buildContent, $versionPattern).Groups[1].Value

if (-not $currentVersion) {
    Write-Error "Could not find VERSION in build.zig"
    exit 1
}

# Split version into components
$versionParts = $currentVersion.Split('.')
$major = [int]$versionParts[0]
$minor = [int]$versionParts[1]
$patch = [int]$versionParts[2]

# Increment version based on type
switch ($VersionType) {
    "major" {
        $major++
        $minor = 0
        $patch = 0
    }
    "minor" {
        $minor++
        $patch = 0
    }
    "patch" {
        $patch++
    }
}

# Create new version string
$newVersion = "$major.$minor.$patch"
Write-Host "Bumping version: $currentVersion → $newVersion"

# Update version in build.zig
$updatedContent = $buildContent -replace $versionPattern, "const VERSION = `"$newVersion`""
Set-Content -Path "build.zig" -Value $updatedContent

# Get most recent tag
try {
    $lastTag = git describe --tags --abbrev=0
} catch {
    $lastTag = ""
    Write-Warning "No previous tags found. Using all history for changelog."
}

# Prepare changelog content
$changelogHeader = "# Zeta $newVersion`n`n"
if ($lastTag) {
    $changes = git log --pretty=format:"- %s" "$lastTag..HEAD"
} else {
    $changes = git log --pretty=format:"- %s"
}

$existingChangelog = Get-Content -Path "CHANGELOG.md" -Raw -ErrorAction SilentlyContinue
if (-not $existingChangelog) {
    $existingChangelog = "# Changelog`n`nAll notable changes to Zeta will be documented in this file.`n"
}

# Create new changelog file
$newChangelog = $changelogHeader + ($changes -join "`n") + "`n`n" + $existingChangelog
Set-Content -Path "CHANGELOG.md" -Value $newChangelog

# Commit changes
git add build.zig CHANGELOG.md
git commit -m "chore: bump version to $newVersion"
git tag -a "v$newVersion" -m "Release v$newVersion"

Write-Host "Version bumped to $newVersion and tagged."
Write-Host "Run 'git push && git push --tags' to publish the new version."
