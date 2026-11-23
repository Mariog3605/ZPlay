# PlayTorrio TV Community — alpha

Unofficial tvOS adaptation of the GPL-3.0 PlayTorrioTVKT codebase, based on the available public source at https://github.com/lucidconviction/PlayTorrioTVKT/tree/87496f3bdab75cc662bc72c97922ab322b14e518 (1.1.2). Not an official release. This is an incremental port, not a complete Android app conversion.

The WatchProgress local percentage, completion/start thresholds, remaining time and resume logic are translated from `domain/model/WatchProgress.kt`; the TV sidebar layout follows `ui/components/SidebarNavigation.kt`. SwiftUI replaces Jetpack Compose and AVKit replaces ExoPlayer. The current alpha supports a manually maintained authorized HTTPS media library, search, persisted local watch progress and native playback. Online catalogs, add-ons, remote synchronization, other media types and P2P are not implemented in this alpha.

The adaptation is distributed under GPL-3.0; the license and corresponding source are provided alongside the build workflow. Upstream contributors retain their copyright.
