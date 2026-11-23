// Installed inside VideoPlayerPlugin.swift to use the same AVPlayer instance.
extension VideoPlayerPlugin {
  func installZPlayTracks(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "zplay/tvos_tracks", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self, self.playersByIdentifier.count == 1,
            let item = self.playersByIdentifier.values.first?.player.currentItem else {
        result(FlutterError(code: "NO_PLAYER", message: "No active video", details: nil)); return
      }
      let args = call.arguments as? [String: Any] ?? [:]
      let kind = args["kind"] as? String == "audio" ? AVMediaCharacteristic.audible : .legible
      guard let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: kind) else {
        result(call.method == "list" ? [] : nil); return
      }
      if call.method == "list" {
        result(group.options.enumerated().map { index, option in
          ["index": index, "name": option.displayName,
           "selected": item.currentMediaSelection.selectedMediaOption(in: group) == option] as [String: Any]
        })
      } else if call.method == "select", let index = args["index"] as? Int {
        if index == -1 && kind == .legible { item.select(nil, in: group); result(nil) }
        else if group.options.indices.contains(index) { item.select(group.options[index], in: group); result(nil) }
        else { result(FlutterError(code: "INVALID_TRACK", message: "Track unavailable", details: nil)) }
      } else { result(FlutterMethodNotImplemented) }
    }
  }
}
