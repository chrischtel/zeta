@echo off
:: release.bat - Version bumping for Zeta project
:: Usage: release.bat [major|minor|patch]

setlocal EnableDelayedExpansion

:: Get version type argument or default to patch
set TYPE=%1
if "%TYPE%"=="" set TYPE=patch

:: Extract current version from build.zig
for /f "tokens=3 delims=^"" %%a in ('findstr /C:"VERSION = " build.zig') do (
    set CURRENT_VERSION=%%a
)

:: Split version into components
for /f "tokens=1,2,3 delims=." %%a in ("!CURRENT_VERSION!") do (
    set MAJOR=%%a
    set MINOR=%%b
    set PATCH=%%c
)

:: Increment version based on type
if "%TYPE%"=="major" (
    set /a MAJOR+=1
    set MINOR=0
    set PATCH=0
) else if "%TYPE%"=="minor" (
    set /a MINOR+=1
    set PATCH=0
) else if "%TYPE%"=="patch" (
    set /a PATCH+=1
) else (
    echo Invalid version type. Use major, minor, or patch.
    exit /b 1
)

:: Create new version string
set NEW_VERSION=%MAJOR%.%MINOR%.%PATCH%
echo Bumping version: %CURRENT_VERSION% → %NEW_VERSION%

:: Update version in build.zig
powershell -Command "(Get-Content build.zig) -replace 'VERSION = \"%CURRENT_VERSION%\"', 'VERSION = \"%NEW_VERSION%\"' | Set-Content build.zig"

:: Get most recent tag
for /f "tokens=*" %%t in ('git describe --tags --abbrev=0') do (
    set LAST_TAG=%%t
)

:: Generate changelog entries
echo # Zeta %NEW_VERSION% > CHANGELOG.new
git log --pretty=format:"- %%s" %LAST_TAG%..HEAD >> CHANGELOG.new
echo. >> CHANGELOG.new
echo. >> CHANGELOG.new
type CHANGELOG.md >> CHANGELOG.new
move /y CHANGELOG.new CHANGELOG.md

:: Commit changes
git add build.zig CHANGELOG.md
git commit -m "chore: bump version to %NEW_VERSION%"
git tag -a "v%NEW_VERSION%" -m "Release v%NEW_VERSION%"

echo Version bumped to %NEW_VERSION% and tagged.
echo Run 'git push ^&^& git push --tags' to publish the new version.

endlocal
