// Community tvOS adaptation of PlayTorrioTVKT 1.1.2 (GPL-3.0).
// Watch progress rules translated from domain/model/WatchProgress.kt.
import SwiftUI
import AVKit

struct WatchProgress: Codable, Identifiable {
    let id: UUID
    var name: String
    var url: URL
    var position: Double = 0
    var duration: Double = 0
    var lastWatched: Date = .distantPast
    var progressPercentage: Double { duration > 0 ? min(1, max(0, position / duration)) : 0 }
    var isCompleted: Bool { progressPercentage >= 0.90 }
    var isInProgress: Bool { progressPercentage >= 0.02 && !isCompleted }
    var remainingTime: Double { max(0, duration - position) }
    func resumePosition(_ actualDuration: Double) -> Double {
        actualDuration > 0 ? min(actualDuration, max(0, position)) : max(0, position)
    }
}

@main struct CommunityApp: App {
    var body: some Scene { WindowGroup { CommunityHome() } }
}

struct CommunityHome: View {
    enum Route: String, CaseIterable { case home = "Home", search = "Search", library = "Library", settings = "Settings" }
    @State private var route = Route.home
    @State private var items: [WatchProgress] = []
    @State private var title = ""
    @State private var address = ""
    @State private var query = ""
    @State private var active: WatchProgress?
    @State private var message = ""
    @AppStorage("resumePlayback") private var resumePlayback = true
    @AppStorage("darkAppearance") private var darkAppearance = true
    private let storage = "communityWatchProgress"

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            HStack(alignment: .top, spacing: 48) {
                VStack(alignment: .leading, spacing: 24) {
                    Text("PLAYTORRIO").font(.title2.bold())
                    Text("COMMUNITY · tvOS").font(.caption).foregroundStyle(.secondary)
                    ForEach(Route.allCases, id: \.self) { tab in
                        Button { route = tab } label: {
                            HStack { Text(tab.rawValue); Spacer(); if tab == route { Image(systemName: "chevron.right") } }
                                .frame(width: 270)
                        }
                    }
                    Spacer()
                }.padding(32).background(Color.white.opacity(0.06))
                ScrollView {
                    VStack(alignment: .leading, spacing: 30) {
                        Text(route.rawValue).font(.largeTitle.bold())
                        switch route {
                        case .home:
                            Text("Continue Watching").font(.title2.bold())
                            cards(items.filter(\.isInProgress))
                            Text("Your media").font(.title2.bold())
                            cards(items)
                            Button("Add authorized media") { route = .library }
                            Button("Public playback test") {
                                let url = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8")!
                                open(WatchProgress(id: UUID(), name: "Apple HLS test", url: url))
                            }
                        case .search:
                            TextField("Search your library", text: $query)
                            cards(items.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) })
                        case .library:
                            TextField("Title", text: $title)
                            TextField("Authorized HTTPS media URL", text: $address)
                            Button("Add to library") { add() }
                            Text(message).foregroundStyle(.orange)
                            cards(items)
                        case .settings:
                            Toggle("Resume playback", isOn: $resumePlayback)
                            Text("Player: native AVKit · audio and subtitle tracks when available")
                            Text("Community port · GPL-3.0 · early alpha")
                            Text("Based on PlayTorrioTVKT 1.1.2. Local library only.").foregroundStyle(.secondary)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 40)
                }
            }.padding(.horizontal, 40)
        }
        .preferredColorScheme(.dark)
        .onAppear { if let data = UserDefaults.standard.data(forKey: storage), let saved = try? JSONDecoder().decode([WatchProgress].self, from: data) { items = saved } }
        .fullScreenCover(item: $active) { entry in
            CommunityPlayback(entry: entry, resume: resumePlayback) { updated in
                if let i = items.firstIndex(where: { $0.id == updated.id }) { items[i] = updated; save() }
            }
        }
    }

    @ViewBuilder private func cards(_ entries: [WatchProgress]) -> some View {
        if entries.isEmpty { Text("Nothing here yet").foregroundStyle(.secondary) }
        else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 24)], spacing: 24) {
                ForEach(entries) { item in
                    Button { open(item) } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            Image(systemName: "play.rectangle.fill").font(.system(size: 64)).frame(maxWidth: .infinity, minHeight: 150)
                            Text(item.name).lineLimit(2)
                            ProgressView(value: item.progressPercentage)
                        }.padding(10)
                    }
                }
            }
        }
    }
    private func add() {
        guard let url = URL(string: address.trimmingCharacters(in: .whitespacesAndNewlines)), url.scheme?.lowercased() == "https", url.host != nil else { message = "Enter a valid HTTPS URL"; return }
        items.insert(WatchProgress(id: UUID(), name: title.isEmpty ? (url.host ?? "Video") : title, url: url), at: 0)
        title = ""; address = ""; message = "Added"; save()
    }
    private func save() { if let data = try? JSONEncoder().encode(items) { UserDefaults.standard.set(data, forKey: storage) } }
    private func open(_ entry: WatchProgress) { active = entry }
}

struct CommunityPlayback: UIViewControllerRepresentable {
    let entry: WatchProgress
    let resume: Bool
    let save: (WatchProgress) -> Void
    final class Coordinator {
        var entry: WatchProgress
        let save: (WatchProgress) -> Void
        var observer: Any?
        init(_ entry: WatchProgress, save: @escaping (WatchProgress) -> Void) { self.entry = entry; self.save = save }
        func update(_ player: AVPlayer) {
            let p = player.currentTime().seconds
            let d = player.currentItem?.duration.seconds ?? 0
            if p.isFinite && p >= 0 { entry.position = p }
            if d.isFinite && d > 0 { entry.duration = d }
            entry.lastWatched = Date(); save(entry)
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator(entry, save: save) }
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        let player = AVPlayer(url: entry.url)
        controller.player = player
        controller.showsPlaybackControls = true
        if resume && !entry.isCompleted && entry.position > 0 { player.seek(to: CMTime(seconds: entry.position, preferredTimescale: 600)) }
        let coordinator = context.coordinator
        coordinator.observer = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 5, preferredTimescale: 600), queue: .main) { [weak player, weak coordinator] _ in
            if let player = player { coordinator?.update(player) }
        }
        player.play(); return controller
    }
    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {}
    static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: Coordinator) {
        if let player = controller.player { coordinator.update(player); if let observer = coordinator.observer { player.removeTimeObserver(observer) }; player.pause() }
    }
}
