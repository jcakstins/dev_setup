#!/usr/bin/env bash
# =============================================================================
#  install/macos.sh — Sensible macOS system defaults
#  Called by bootstrap.sh; safe to re-run (idempotent via defaults write)
#  Requires: macOS 15 Sequoia
#
#  NOTE: Many settings require logging out or restarting apps to take effect.
#  The script restarts affected system services at the end.
# =============================================================================
set -euo pipefail

log()  { printf '\033[0;32m==>\033[0m %s\n' "$*"; }
info() { printf '\033[0;34m   →\033[0m %s\n' "$*"; }

log "Applying macOS defaults"

# ── Keyboard ──────────────────────────────────────────────────────────────────
log "Keyboard"

# Fast key repeat (lower = faster; minimum is 1)
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Disable press-and-hold accent popup — enables proper key repeat in editors
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Disable autocorrect and smart substitutions
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

info "Key repeat: KeyRepeat=2, InitialKeyRepeat=15"
info "Press-and-hold disabled, smart substitutions disabled"

# ── Trackpad ──────────────────────────────────────────────────────────────────
log "Trackpad"

# Enable tap-to-click
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Enable three-finger drag
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true

# Tracking speed (0–3)
defaults write NSGlobalDomain com.apple.trackpad.scaling -float 2.0

info "Tap-to-click enabled"
info "Three-finger drag enabled"
info "Tracking speed: 2.0"

# ── Finder ────────────────────────────────────────────────────────────────────
log "Finder"

# Show path bar and status bar
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true

# Show all file extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Show hidden files
defaults write com.apple.finder AppleShowAllFiles -bool true

# Default to list view in all Finder windows
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Search in current folder by default (not the whole Mac)
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# Disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Disable .DS_Store on network and USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Show the ~/Library folder
chflags nohidden ~/Library

# New Finder window shows home directory
defaults write com.apple.finder NewWindowTarget -string "PfHm"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/"

info "Path bar, status bar, list view, hidden files, no DS_Store on network"

# ── Dock ──────────────────────────────────────────────────────────────────────
log "Dock"

# Auto-hide dock
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.3

# Don't show recent apps in Dock
defaults write com.apple.dock show-recents -bool false

# Smaller dock size
defaults write com.apple.dock tilesize -int 48

info "Dock: auto-hide, no recent apps, size 48"

# ── Screenshots ───────────────────────────────────────────────────────────────
log "Screenshots"

# Save screenshots to ~/Desktop/Screenshots
mkdir -p "${HOME}/Desktop/Screenshots"
defaults write com.apple.screencapture location -string "${HOME}/Desktop/Screenshots"

# Save as PNG
defaults write com.apple.screencapture type -string "png"

# Disable shadow in screenshots
defaults write com.apple.screencapture disable-shadow -bool true

info "Screenshots → ~/Desktop/Screenshots (PNG, no shadow)"

# ── Activity Monitor ──────────────────────────────────────────────────────────
log "Activity Monitor"

# Show all processes
defaults write com.apple.ActivityMonitor ShowCategory -int 0

# Sort by CPU usage
defaults write com.apple.ActivityMonitor SortColumn -string "CPUUsage"
defaults write com.apple.ActivityMonitor SortDirection -int 0

# ── Misc ──────────────────────────────────────────────────────────────────────
log "Miscellaneous"

# Disable the "Are you sure you want to open this application?" dialog
defaults write com.apple.LaunchServices LSQuarantine -bool false

# Expand save panel by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# Expand print panel by default
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

# Save to disk (not iCloud) by default
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

# ── Restart affected apps ─────────────────────────────────────────────────────
log "Restarting affected system apps"

for app in "Finder" "Dock" "SystemUIServer"; do
  killall "$app" &>/dev/null || true
  info "Restarted ${app}"
done

log "macOS defaults applied. Some changes require a logout/restart to fully take effect."
