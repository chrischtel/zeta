# release.ps1 - Version management for Zeta project
# Usage:
#   ./release.ps1 [major|minor|patch|none]           # Standard release (none = keep version)
#   ./release.ps1 [major|minor|patch|none] -pre alpha # Pre-release (alpha, beta, rc)
#   ./release.ps1 promote                        # Promote pre-release to full release
#   ./release.ps1 hotfix  

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

function Get-MeaningfulChanges {
    param (
        [string[]]$CommitMessages
    )
    
    $features = @()
    $fixes = @()
    $other = @()
    $breaking = @()
    
    foreach ($msg in $CommitMessages) {
        # Look for breaking changes first
        if ($msg -match '^\- (feat|fix|perf|refactor)!:') {
            $breaking += $msg -replace '^\- (feat|fix|perf|refactor)!:', '- '
            continue
        }
        
        # Only include conventionally formatted commits
        if ($msg -match '^\- (feat|fix|perf|refactor|docs|style|test|ci|chore|hotfix):') {
            # Clean up the message a bit
            $cleanMsg = $msg -replace '^\- ', '- '
            
            # Categorize changes
            if ($msg -match '^\- (fix|hotfix):') {
                $fixes += $cleanMsg
            }
            elseif ($msg -match '^\- feat:') {
                $features += $cleanMsg
            }
            elseif ($msg -match '^\- (perf|refactor):') {
                $other += $cleanMsg
            }
        }
    }
    
    $result = @()
    
    if ($breaking.Count -gt 0) {
        $result += "### ⚠️ BREAKING CHANGES"
        $result += ""
        $result += $breaking
        $result += ""
    }
    
    if ($features.Count -gt 0) {
        $result += "### New Features"
        $result += ""
        $result += $features
        $result += ""
    }
    
    if ($fixes.Count -gt 0) {
        $result += "### Bug Fixes"
        $result += ""
        $result += $fixes
        $result += ""
    }
    
    if ($other.Count -gt 0) {
        $result += "### Other Improvements"
        $result += ""
        $result += $other
        $result += ""
    }
    
    return $result
}

# Validate inputs and parameters
if ($VersionType -notin @("major", "minor", "patch", "promote", "hotfix", "none")) {
    Write-Status "Invalid version type. Use major, minor, patch, promote, hotfix, or none." "error"
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
$versionPattern = '(?m)^const VERSION = "([^"]+)"'
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
    $lastTagDate = git log -1 --format=%ai $lastTag 2>$null
    $lastTagDateFormatted = if ($lastTagDate) { [DateTime]::Parse($lastTagDate).ToString("yyyy-MM-dd") } else { "" }
}
catch {
    $lastTag = ""
    $lastTagDateFormatted = ""
}

# Create changelog header
$changelogHeader = "# $newVersion"
if ($Pre) {
    $changelogHeader += " ($Pre)"
}
elseif ($Hotfix) {
    $changelogHeader += " (Hotfix)"
}

$releaseDate = Get-Date -Format "yyyy-MM-dd"
$changelogHeader += "`n`nReleased on $releaseDate"
if ($lastTagDateFormatted) {
    $changelogHeader += " (changes since $lastTagDateFormatted)"
}
$changelogHeader += "`n`n"

# Get conventional commits from git log with more details
if ($lastTag) {
    $rawCommits = git log --pretty=format:"%s|%h|%an" "$lastTag..HEAD"
}
else {
    $rawCommits = git log --pretty=format:"%s|%h|%an" -n 50  # Limit to last 50 commits if no tags exist
}

# Process commits to include hash links
$processedCommits = @()
foreach ($commit in $rawCommits) {
    $parts = $commit -split '\|'
    if ($parts.Count -ge 2) {
        $message = $parts[0]
        $hash = $parts[1]
        $author = if ($parts.Count -ge 3) { $parts[2] } else { "" }
        
        # Keep just the original format for processing
        $processedCommits += "- $message"
    }
}

# Filter to only include meaningful changes
$changes = Get-MeaningfulChanges -CommitMessages $processedCommits
if ($changes.Count -eq 0) {
    $changes = @("- No significant changes in this release")
}

# Add contributors section
$contributors = @()
if ($lastTag) {
    $contributors = git log "$lastTag..HEAD" --format="%an" | Sort-Object -Unique
}

if ($contributors.Count -gt 0) {
    $contributorsSection = "`n### Contributors`n`n" + 
    ($contributors | ForEach-Object { "- $_" }) -join "`n"

    $changelogText = $changelogHeader + ($changes -join "`n") + "`n" + $contributorsSection + "`n`n"
}
else {
    $changelogText = $changelogHeader + ($changes -join "`n") + "`n`n"
}

# Backup existing changelog
if (Test-Path "CHANGELOG.md") {
    Copy-Item "CHANGELOG.md" "CHANGELOG.md.bak"
    Write-Status "Created backup of CHANGELOG.md" "info"
    
    # Check if version already exists in changelog
    $existingChangelog = Get-Content -Path "CHANGELOG.md" -Raw
    if ($existingChangelog -match "# $newVersion(\s|\(|$)") {
        Write-Status "Version $newVersion already exists in changelog" "warning"
        $overwrite = Read-Host "Do you want to overwrite it? (y/N)"
        if ($overwrite -ne "y" -and $overwrite -ne "Y") {
            Write-Status "Keeping existing changelog entry" "info"
            Remove-Item "CHANGELOG.md.bak"
            return
        }
    }
    
    # Extract title and header
    $title = "# Changelog"
    
    # Extract existing release entries (each starts with "# X.X.X")
    $pattern = "(?s)# \d+\.\d+\.\d+.*?(?=# \d+\.\d+\.\d+|$)"
    $entries = [regex]::Matches($existingChangelog, $pattern)
    
    # Keep only the specified number of recent entries
    $recentEntries = @()
    $count = 0
    
    foreach ($entry in $entries) {
        # Skip if this is the same version we're currently releasing
        if ($entry.Value -match "^# $newVersion(\s|\(|$)") {
            continue
        }
        
        if ($count -lt $MaxChangelogEntries - 1) {
            # -1 to account for the new entry
            $recentEntries += $entry.Value
        }
        $count++
        if ($count -ge $MaxChangelogEntries - 1) {
            break
        }
    }
    
    # Add a note about older releases
    $footer = "`n## Older Releases`n`nFor older releases, please see the [GitHub Releases page](https://github.com/$RepoOwner/$RepoName/releases).`n"
    
    # Combine everything
    $joinedEntries = $recentEntries -join ""
    $newChangelog = "$title`n`n$changelogText$joinedEntries$footer"
}
else {
    $newChangelog = "# Changelog`n`n$changelogText"
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
