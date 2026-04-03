# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`stuffie-crossing` is a prototype Swift game. The project targets iOS/macOS and uses Xcode as the primary IDE with Swift Package Manager for dependency management.

## Build & Run

This project requires Xcode. Once source files and a project manifest exist:

```bash
# Swift Package Manager
swift build
swift run

# Xcode (headless)
xcodebuild -scheme <SchemeName> build
xcodebuild -scheme <SchemeName> -destination 'platform=iOS Simulator,name=iPhone 15' build
```

## Testing

```bash
swift test                          # Run all tests via SPM
swift test --filter <TestName>      # Run a single test
xcodebuild test -scheme <SchemeName> -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Dependency Managers

The `.gitignore` is configured for Swift Package Manager, CocoaPods, Carthage, and fastlane — any of these may be introduced as the project grows.
