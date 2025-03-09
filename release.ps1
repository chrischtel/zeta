# release.ps1 - Version bumping for Zeta project
# Usage:
#   .\release.ps1 [major|minor|patch]
#   .\release.ps1 [major|minor|patch] -PreReleaseType alpha
#   .\release.ps1 promote -FromPreRelease  # Promotes current pre-release to full release

param(
    [Parameter(Position = 0)]
    [string]$VersionType = "patch",

    [Parameter()]
    [string]$PreReleaseType = "",

    [Parameter()]
    [switch]$FromPreRelease = $false,

    [Parameter()]
    [switch]$DryRun = $false
)

# Validate version type
if ($VersionType -notin @("major", "minor", "patch", "none", "promote")) {
    Write-Error "Invalid version type. Use major, minor, patch, none, or promote."
    exit 1
}

# Validate promotion parameters
if ($VersionType -eq "promote" -and -not $FromPreRelease) {
    Write-Error "Promotion requires -FromPreRelease switch"
    exit 1
}

# Validate prerelease parameters
$isPreRelease = $false
if ($PreReleaseType -ne "") {
    $isPreRelease = $true
    if ($PreReleaseType -notin @("alpha", "beta", "rc")) {
        Write-Warning "Unusual prerelease type: $PreReleaseType. Common types are alpha, beta, rc."
    }
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

Write-Host "Current version: $currentVersion"

# Handle promotion from pre-release to full release
if ($VersionType -eq "promote" -and $FromPreRelease) {
    if (-not ($currentVersion -match "^(\d+\.\d+\.\d+)-(.+)(\+.+)?$")) {
        Write-Error "Current version '$currentVersion' is not a pre-release version"
        exit 1
    }
    
    $newVersion = $Matches[1]
    Write-Host "Promoting pre-release $currentVersion to full release $newVersion"
    $fullVersion = $newVersion
    
    # Update files and create commits/tags below
}
else {
    # Strip any existing prerelease/build info for normal versioning
    $baseVersion = $currentVersion -replace '-.*', ''

    # Split version into components
    $versionParts = $baseVersion.Split('.')
    $major = [int]$versionParts[0]
    $minor = [int]$versionParts[1]
    $patch = [int]$versionParts[2]

    # Increment Version based on type - Only if NOT a prerelease
    if ($VersionType -ne "none") {
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
    }

    # Create new version string - the BASE version
    $newVersion = "$major.$minor.$patch"

    # Handle Pre-release versioning
    if ($isPreRelease) {
        # Strip the git hash BEFORE matching
        $currentVersionWithoutHash = $currentVersion -replace '\+.*', ''

        Write-Host "Base version: $baseVersion"
        
        #Check if there is a prerelease number
        if ($currentVersionWithoutHash -match "-$PreReleaseType\.(\d+)$") {
            #Get the current prerelease version
            $currentPreReleaseVersion = [int]$Matches[1]
            
            #Increment it
            $nextPreReleaseVersion = $currentPreReleaseVersion + 1
            Write-Host "Incrementing existing $PreReleaseType version to $nextPreReleaseVersion"
            $fullVersion = "$newVersion-$PreReleaseType.$nextPreReleaseVersion+$gitHash"
        }
        else {
            #No existing prerelease number, so use 1
            $nextPreReleaseVersion = 1
            Write-Host "Setting $PreReleaseType version to $nextPreReleaseVersion"
            $fullVersion = "$newVersion-$PreReleaseType.$nextPreReleaseVersion+$gitHash"
        }
    }
    else {
        $fullVersion = $newVersion # No Git hash for official releases
    }
}

Write-Host "New version: $fullVersion"

if ($DryRun) {
    Write-Host "DRY RUN: Would update files with version $fullVersion"
    exit 0
}

# Update version in build.zig
$updatedContent = $buildContent -replace $versionPattern, "const VERSION = `"$fullVersion`""
Set-Content -Path "build.zig" -Value $updatedContent

# Update version in build.zig.zon
$versionZonPattern = '\.version = "([\d\.]+[^"]*)"'
$buildZonContent = Get-Content -Path "build.zig.zon" -Raw
$replacementZonVersion = ".version = `"$newVersion`""
$buildZonUpdatedContent = $buildZonContent -replace $versionZonPattern, $replacementZonVersion
Set-Content -Path "build.zig.zon" -Value $buildZonUpdatedContent

# Get most recent tag for changelog
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

# Append Git hash to the changelog entry for pre-releases
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
git add build.zig build.zig.zon CHANGELOG.md
git commit -m "chore: bump version to $fullVersion"

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
Write-Host "Or use the GitHub Actions workflow to automate the release process."
