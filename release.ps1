# release.ps1 - Version bumping for Zeta project
# Usage:
#   .\release.ps1 [major|minor|patch]
#   .\release.ps1 [major|minor|patch] -PreReleaseType alpha -PreReleaseVersion 1

param(
    [Parameter(Position = 0)]
    [string]$VersionType = "patch",

    [Parameter()]
    [string]$PreReleaseType = "",

    [Parameter()]
    [string]$PreReleaseVersion = ""
)

# Validate version type
if ($VersionType -notin @("major", "minor", "patch")) {
    Write-Error "Invalid version type. Use major, minor, or patch."
    exit 1
}

# Validate prerelease parameters
$isPreRelease = $false
if ($PreReleaseType -ne "") {
    $isPreRelease = $true
    if ($PreReleaseType -notin @("alpha", "beta", "rc")) {
        Write-Warning "Unusual prerelease type: $PreReleaseType. Common types are alpha, beta, rc."
    }

    #if ($PreReleaseVersion -eq "") { #No longer needed because we increment it in the script now
    #    $PreReleaseVersion = "1" # Default to 1 if not specified
    #}
}

# Get current git hash
$gitHash = git rev-parse --short HEAD

# Extract current version from build.zig
$versionPattern = 'const VERSION = "([\d\.]+[^"]*)"'
$buildContent = Get-Content -Path "build.zig" -Raw
$currentVersion = [regex]::Match($buildContent, $versionPattern).Groups[1].Value

if (-not $currentVersion) {
    Write-Error "Could not find VERSION in build.zig"
    exit 1
}

# Strip any existing prerelease/build info
$baseVersion = $currentVersion -replace '-.*', ''

# Split version into components
$versionParts = $baseVersion.Split('.')
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

# Handle Pre-release versioning
if ($isPreRelease) {
    #Check if there is a prerelease number
    if ($currentVersion -match "-$PreReleaseType\.(\d+)$") {
        #Get the current prerelease version
        $currentPreReleaseVersion = [int]$Matches[1]

        #Increment it
        $PreReleaseVersion = $currentPreReleaseVersion + 1
        Write-Host "Incrementing existing $PreReleaseType version to $PreReleaseVersion"
    }
    else {
        #No existing prerelease number, so use 1
        $PreReleaseVersion = 1
        Write-Host "Setting $PreReleaseType version to $PreReleaseVersion"
    }
    $fullVersion = "$newVersion-$PreReleaseType.$PreReleaseVersion+$gitHash" # Include Git hash for pre-releases
}
else {
    $fullVersion = $newVersion # No Git hash for official releases
}

Write-Host "Bumping version: $currentVersion → $fullVersion"

# Update version in build.zig
$updatedContent = $buildContent -replace $versionPattern, "const VERSION = `"$fullVersion`""
Set-Content -Path "build.zig" -Value $updatedContent

# Get most recent tag
try {
    $lastTag = git describe --tags --abbrev=0
}
catch {
    $lastTag = ""
    Write-Warning "No previous tags found. Using all history for changelog."
}

# Prepare changelog content
$changelogHeader = "# Zeta $newVersion`n`n"
if ($lastTag) {
    $changes = git log --pretty=format:"- %s" "$lastTag..HEAD"
}
else {
    $changes = git log --pretty=format:"- %s"
}

# Append Git hash to the changelog entry IFF it's a pre-release
if ($isPreRelease) {
    $changelogHeader = "$changelogHeader (Build: $gitHash)`n`n"
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

# Create a tag
if ($isPreRelease) {
    git tag -a "v$fullVersion" -m "Release v$fullVersion"
    Write-Host "Prerelease version bumped to $fullVersion and tagged."
}
else {
    git tag -a "v$newVersion" -m "Release v$newVersion"
    Write-Host "Version bumped to $fullVersion and tagged."
}
Write-Host "Run 'git push && git push --tags' to publish the new version."
