# Convenience wrappers. See FACTORY.md for full details.

XCODEGEN := xcodegen
SWIFT    := swift
XCODEBUILD := xcodebuild

PROJECT  := SlothIOS.xcodeproj
SCHEME   := SlothIOS
DEST     := platform=iOS Simulator,name=iPhone 17 Pro

.PHONY: all generate build test test-core test-app clean

all: generate build

# Regenerate the Xcode project from project.yml.
generate:
	$(XCODEGEN) generate

# Build the iOS app (regenerates first).
build: generate
	$(XCODEBUILD) -scheme $(SCHEME) -destination '$(DEST)' build

# Run all tests: headless SlothCore + Xcode unit tests.
test: test-core test-app

# Pure-Swift headless tests. No Xcode required.
test-core:
	$(SWIFT) test

# Xcode unit tests (requires xcodegen + Xcode CLT).
test-app: generate
	$(XCODEBUILD) -scheme $(SCHEME) -destination '$(DEST)' test

clean:
	rm -rf .build DerivedData $(PROJECT)
