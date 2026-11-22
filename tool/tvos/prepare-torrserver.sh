#!/usr/bin/env bash
# Build native, arm64 tvOS engine rather than reusing an iOS framework.
set -euo pipefail
root="$PWD"
plugin="$RUNNER_TEMP/torrserver_flutter_tvos"
engine="$RUNNER_TEMP/torrserver-src"
mobile="$RUNNER_TEMP/gomobile-tvos"
git clone --branch v0.0.7 --depth 1 https://github.com/tzero86/torrserver_flutter.git "$plugin"
git clone https://github.com/YouROK/TorrServer.git "$engine"
git -C "$engine" checkout d9fda7bde199a13a1ba0be03c7f1f7e60e8a340d
git clone https://github.com/netbirdio/gomobile-tvos-fork.git "$mobile"
git -C "$mobile" checkout a56582c0e7c97feda06c4f8a74995129e6b3f89a

# The HTTP API must not listen on the LAN. The embedded engine is private
# to this device; no remote management or other inbound API is enabled.
python3 - "$engine/server/mobile/torrserverkit/torrserverkit.go" "$plugin" "$root/pubspec.yaml" <<'PY'
import pathlib, sys
shim, plugin, pubspec = map(pathlib.Path, sys.argv[1:])
s = shim.read_text()
assert 'Port:     portStr,' in s
shim.write_text(s.replace('Port:     portStr,','Port:     portStr,\n\t\tIPs: []string{"127.0.0.1"},').replace('SearchWA: true,','SearchWA: false,'))
p = plugin / 'pubspec.yaml'
s = p.read_text()
assert '      ios:\n' in s
p.write_text(s.replace('      ios:\n','      tvos:\n        pluginClass: TorrserverFlutterPlugin\n      ios:\n'))
p = plugin / 'lib/torrserver_flutter.dart'
s = p.read_text()
assert 'if (Platform.isIOS)' in s
p.write_text(s.replace('if (Platform.isIOS)', "if (Platform.isIOS || Platform.operatingSystem == 'tvos')"))
p = plugin / 'lib/src/torrserver_controller_ios.dart'
s = p.read_text()
p.write_text(s.replace('getApplicationSupportDirectory()', 'getTemporaryDirectory()'))
s = pubspec.read_text()
old = '  torrserver_flutter:\n    git:\n      url: https://github.com/tzero86/torrserver_flutter.git\n      ref: v0.0.7'
assert old in s
pubspec.write_text(s.replace(old, f'  torrserver_flutter:\n    path: {plugin}'))
PY

mkdir -p "$plugin/tvos/Classes" "$RUNNER_TEMP/tvos-go-bin"
cp "$plugin/ios/Classes/TorrserverFlutterPlugin.swift" "$plugin/tvos/Classes/"
export GOBIN="$RUNNER_TEMP/tvos-go-bin"
export PATH="$GOBIN:$PATH"
cd "$mobile"
go install ./cmd/gomobile-netbird ./cmd/gobind-netbird
cd "$engine/server/mobile/torrserverkit"
go mod edit -require=github.com/netbirdio/gomobile-tvos-fork@v0.0.0
go mod edit -replace="github.com/netbirdio/gomobile-tvos-fork=$mobile"
go mod download
gomobile-netbird bind -target=tvos/arm64 -tvosversion=15.0 -tags=nosqlite \
  -ldflags='-s -w -checklinkname=0' -trimpath \
  -o "$plugin/tvos/TorrServerKit.xcframework" .
test -d "$plugin/tvos/TorrServerKit.xcframework"
/usr/libexec/PlistBuddy -c 'Print :AvailableLibraries:0:SupportedPlatform' \
  "$plugin/tvos/TorrServerKit.xcframework/Info.plist" | grep -Fx tvos

cd "$root"
cp tool/tvos/torrserver_flutter.podspec "$plugin/tvos/"
cp tool/tvos/Package.swift "$plugin/tvos/"
# Restrict ATS relaxation to local networking, not arbitrary remote HTTP.
/usr/libexec/PlistBuddy -c 'Add :NSAppTransportSecurity dict' tvos/Runner/Info.plist 2>/dev/null || true
/usr/libexec/PlistBuddy -c 'Add :NSAppTransportSecurity:NSAllowsLocalNetworking bool true' tvos/Runner/Info.plist 2>/dev/null || \
  /usr/libexec/PlistBuddy -c 'Set :NSAppTransportSecurity:NSAllowsLocalNetworking true' tvos/Runner/Info.plist
