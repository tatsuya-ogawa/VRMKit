PLATFORM_IOS = iOS Simulator,id=$(call udid_for_latest,iPhone,iOS)
PLATFORM_WATCHOS = watchOS Simulator,id=$(call udid_for_latest,Watch,watchOS)
PLATFORM_VISIONOS = visionOS Simulator,id=$(call udid_for_latest,Apple Vision Pro,xrOS)

test: test-package

test-package:
	for platform in "$(PLATFORM_IOS)" "$(PLATFORM_WATCHOS)" "$(PLATFORM_VISIONOS)"; do\
		xcodebuild test -scheme VRMKit-Package -destination platform="$$platform" || exit 1;\
	done

define udid_for_latest
$(shell xcrun simctl list --json devices available | jq -r --arg name "$(1)" --arg platform "$(2)" 'def ver(k): (k | capture("SimRuntime\\." + $$platform + "-(?<major>\\d+)-(?<minor>\\d+)")) as $$m | [$$m.major|tonumber, $$m.minor|tonumber]; .devices | to_entries | map(select(.key | test("SimRuntime\\." + $$platform + "-\\d+-\\d+"))) | sort_by(ver(.key)) | last | .value | map(select(.name | contains($$name))) | last | .udid // empty')
endef
