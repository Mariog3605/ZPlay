"""Extend a pinned tvOS player with AVFoundation media-selection controls."""
from pathlib import Path
import sys

plugin, extension = map(Path, sys.argv[1:])
source = plugin / 'tvos/Classes/video_player_avfoundation/VideoPlayerPlugin.swift'
text = source.read_text()
marker = 'AVFoundationVideoPlayerApiSetup.setUp(binaryMessenger: messenger, api: instance)'
assert text.count(marker) == 1
source.write_text(text.replace(marker, marker + '\n    instance.installZPlayTracks(messenger)') + '\n' + extension.read_text())
pubspec = Path('pubspec.yaml')
text = pubspec.read_text()
marker = 'dependency_overrides:\n'
assert text.count(marker) == 1
pubspec.write_text(text.replace(marker, marker + f'  video_player_tvos:\n    path: {plugin}\n'))
