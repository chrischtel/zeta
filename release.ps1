# release.ps1 - Version management for Zeta project
# Usage:
#   ./release.ps1 [major|minor|patch]           # Standard release
#   ./release.ps1 [major|minor|patch] -pre alpha # Pre-release (alpha, beta, rc)
#   ./release.ps1 promote                        # Promote pre-release to full release
#   ./release.ps1 hotfix                         # Create a hotfix

param(
    [Parameter(Position = 0)]
    [string]$VersionType = "patch",

    [Parameter()]
    [string]$Pre = "",

    [Parameter()]
    [switch]$Promote = $false,
    
    [Parameter()]
    [switch]$Hotfix = $false,

    [Parameter()]
    [switch]$DryRun = $false,

    [Parameter()]
    [switch]$NoPush = $false
)

function Write-Status {
    param ([string]$Message, [string]$Type = "info")
    
    $color = switch ($Type) {
        "info" { "Cyan" }
        "success" { "Green" }
        "warning" { "Yellow" }
        "error" { "Red" }
        default { "White" }
    }
    
    Write-Host "[$Type] " -ForegroundColor $color -NoNewLine
    Write-Host "$Message"
}

# Validate inputs and parameters
if ($VersionType -notin @("major", "minor", "patch", "promote", "hotfix")) {
    Write-Status "Invalid version type. Use major, minor, patch, promote, or hotfix." "error"
    exit 1
}

if ($Hotfix -and $VersionType -ne "hotfix") {
    Write-Status "Use either -Hotfix switch or 'hotfix' as the version type, not both." "error"
    exit 1
}

if ($VersionType -eq "hotfix") {
    $Hotfix = $true
    $VersionType = "patch"  # Hotfixes are always patch versions
}

if ($Pre -ne "" -and $Pre -notin @("alpha", "beta", "rc")) {
    Write-Status "Non-standard pre-release type: $Pre. Continuing anyway." "warning"
}

if ($VersionType -eq "promote" -and $Pre -ne "") {
    Write-Status "Cannot specify pre-release type when promoting." "error"
    exit 1
}

# Check current branch
$currentBranch = git rev-parse --abbrev-ref HEAD
Write-Status "Current branch: $currentBranch" "info"

# Validate branch based on operation
if ($Hotfix -and $currentBranch -ne "main" -and -not $currentBranch.StartsWith("hotfix/")) {
    Write-Status "Hotfixes should be created from 'main' or a 'hotfix/' branch." "warning"
    $confirmation = Read-Host "Continue anyway? (y/N)"
    if ($confirmation -ne "y") {
        exit 0
    }
}

if (-not $Hotfix -and $VersionType -ne "promote" -and $currentBranch -ne "develop" -and -not $currentBranch.StartsWith("release/")) {
    Write-Status "Regular releases should be created from 'develop' or a 'release/' branch." "warning"
    $confirmation = Read-Host "Continue anyway? (y/N)"
    if ($confirmation -ne "y") {
        exit 0
    }
}

# Get current git hash
try {
    $gitHash = git rev-parse --short HEAD
}
catch {
    Write-Status "Failed to get git hash. Make sure git is installed and this is a git repository." "error"
    exit 1
}

# Check for uncommitted changes
$gitStatus = git status --porcelain
if ($gitStatus) {
    Write-Status "You have uncommitted changes. Commit or stash them before creating a release." "warning"
    Write-Status "Run with -DryRun to test without making changes." "info"
    if (-not $DryRun) {
        $confirmation = Read-Host "Continue anyway? (y/N)"
        if ($confirmation -ne "y") {
            exit 0
        }
    }
}

# Get current version from build.zig
$versionPattern = 'const VERSION = "([^"]+)"'
try {
    $buildContent = Get-Content -Path "build.zig" -Raw
    $match = [regex]::Match($buildContent, $versionPattern)
    if (-not $match.Success) {
        throw "VERSION not found"
    }
    $currentVersion = $match.Groups[1].Value
}
catch {
    Write-Status "Failed to read version from build.zig: $_" "error"
    exit 1
}

Write-Status "Current version: $currentVersion" "info"

# Parse the current version
$versionRegex = '^(\d+)\.(\d+)\.(\d+)(?:-([^+]+))?(?:\+(.+))?$'
$versionMatch = [regex]::Match($currentVersion, $versionRegex)

if (-not $versionMatch.Success) {
    Write-Status "Current version does not match semantic versioning pattern" "error"
    exit 1
}

$major = [int]$versionMatch.Groups[1].Value
$minor = [int]$versionMatch.Groups[2].Value
$patch = [int]$versionMatch.Groups[3].Value
$prerelease = if ($versionMatch.Groups[4].Success) { $versionMatch.Groups[4].Value } else { "" }

# Determine new version
if ($Promote -or $VersionType -eq "promote") {
    # Promoting from pre-release to full release
    if (-not $prerelease) {
        Write-Status "Current version is not a pre-release. Nothing to promote." "error"
        exit 1
    }
    
    $newVersion = "$major.$minor.$patch"
    Write-Status "Promoting $currentVersion to $newVersion" "info"
}
else {
    # Regular version bump
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
    
    $newVersion = "$major.$minor.$patch"
    
    # Handle pre-release
    if ($Pre) {
        # Check if it's the same pre-release type
        if ($prerelease -match "^$Pre\.(\d+)$") {
            $preNumber = [int]$Matches[1] + 1
        }
        else {
            $preNumber = 1
        }
        
        $newVersion = "$newVersion-$Pre.$preNumber+$gitHash"
    }
    
    # For hotfixes, add a hotfix identifier
    if ($Hotfix) {
        if (-not $Pre) {
            # Only add the git hash for hotfixes if it's not a pre-release
            $newVersion = "$newVersion+$gitHash"
        }
    }
}

Write-Status "New version will be: $newVersion" "info"

if ($DryRun) {
    Write-Status "DRY RUN - No changes were made" "warning"
    exit 0
}

# Update version in build.zig
$updatedContent = $buildContent -replace $versionPattern, "const VERSION = `"$newVersion`""
Set-Content -Path "build.zig" -Value $updatedContent -NoNewline

# Update version in build.zig.zon if it exists
if (Test-Path "build.zig.zon") {
    $versionZonPattern = '\.version = "([^"]+)"'
    $buildZonContent = Get-Content -Path "build.zig.zon" -Raw
    $updatedZonContent = $buildZonContent -replace $versionZonPattern, ".version = `"$newVersion`""
    Set-Content -Path "build.zig.zon" -Value $updatedZonContent -NoNewline
    Write-Status "Updated version in build.zig.zon" "success"
}

# Create/update changelog
try {
    # Get the latest tag
    $lastTag = git describe --tags --abbrev=0 2>$null
}
catch {
    $lastTag = ""
}

$changelogHeader = "# $newVersion"
if ($Pre) {
    $changelogHeader += " ($Pre)"
}
elseif ($Hotfix) {
    $changelogHeader += " (Hotfix)"
}
$changelogHeader += "`n`nReleased on $(Get-Date -Format "yyyy-MM-dd")`n`n"

if ($lastTag) {
    $changes = git log --pretty=format:"- %s" "$lastTag..HEAD" | Where-Object { $_ -notmatch '^chore:' }
}
else {
    $changes = git log --pretty=format:"- %s" | Where-Object { $_ -notmatch '^chore:' }
}

if (-not $changes) {
    $changes = @("- No significant changes")
}

$changelogText = $changelogHeader + ($changes -join "`n") + "`n`n"

if (Test-Path "CHANGELOG.md") {
    $existingChangelog = Get-Content -Path "CHANGELOG.md" -Raw
    $newChangelog = $changelogText + $existingChangelog
}
else {
    $newChangelog = "# Changelog`n`n" + $changelogText
}

Set-Content -Path "CHANGELOG.md" -Value $newChangelog -NoNewline
Write-Status "Updated CHANGELOG.md" "success"

# Commit changes
git add build.zig CHANGELOG.md
if (Test-Path "build.zig.zon") {
    git add build.zig.zon
}

$commitMessage = if ($Hotfix) {
    "chore: hotfix version $newVersion"
}
elseif ($Pre) {
    "chore: pre-release version $newVersion"
}
else {
    "chore: release version $newVersion"
}

git commit -m $commitMessage
$tagName = "v$newVersion"

# Create tag
if ($Pre) {
    git tag -a $tagName -m "Pre-release $newVersion"
    Write-Status "Created pre-release tag $tagName" "success"
}
elseif ($Hotfix) {
    git tag -a $tagName -m "Hotfix $newVersion"
    Write-Status "Created hotfix tag $tagName" "success"
}
else {
    git tag -a $tagName -m "Release $newVersion"
    Write-Status "Created release tag $tagName" "success"
}

# Push changes if requested
if (-not $NoPush) {
    git push origin $currentBranch
    git push origin $tagName
    Write-Status "Pushed changes and tag to remote" "success"
    Write-Status "GitHub Actions will now build and publish the release" "info"
}
else {
    Write-Status "Changes committed locally. Run 'git push && git push --tags' to trigger CI" "info"
}

# Provide guidance for branch management
if ($Hotfix) {
    Write-Status "Hotfix branch workflow:" "info"
    Write-Status "1. Merge this hotfix back to 'main': git checkout main && git merge $currentBranch" "info"
    Write-Status "2. Merge this hotfix to 'develop' as well: git checkout develop && git merge $currentBranch" "info"
    Write-Status "3. Delete the hotfix branch when done: git branch -d $currentBranch" "info"
}
elseif ($currentBranch.StartsWith("release/")) {
    Write-Status "Release branch workflow:" "info"
    Write-Status "1. Merge this release to 'main': git checkout main && git merge $currentBranch" "info" 
    Write-Status "2. Merge this release back to 'develop': git checkout develop && git merge $currentBranch" "info"
    Write-Status "3. Delete the release branch when done: git branch -d $currentBranch" "info"
}
