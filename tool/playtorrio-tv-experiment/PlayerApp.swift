import SwiftUI
import AVKit

@main
struct PlayerExperiment: App {
    var body: some Scene { WindowGroup { HomeScreen() } }
}

struct HomeScreen: View {
    @State private var address = ""
    @State private var player: AVPlayer?
    @State private var message = ""
    @FocusState private var focus: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let player = player {
                NativePlayer(player: player).ignoresSafeArea()
                    .onExitCommand { player.pause(); self.player = nil }
            } else {
                VStack(alignment: .leading, spacing: 32) {
                    Text("TV Player Experiment").font(.largeTitle.bold())
                    Text("Independent tvOS prototype • PlayTorrio-inspired")
                        .foregroundStyle(.secondary)
                    TextField("Authorized HTTPS video URL", text: $address)
                        .focused($focus)
                    HStack(spacing: 20) {
                        Button("Play video") { open(address) }
                        Button("Public playback test") {
                            open("https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8")
                        }
                    }
                    Text(message).foregroundStyle(.orange)
                    Spacer()
                }.padding(80)
                .onAppear { focus = true }
            }
        }.preferredColorScheme(.dark)
    }

    private func open(_ input: String) {
        guard let url = URL(string: input.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.lowercased() == "https", url.host != nil else {
            message = "Enter a valid HTTPS media URL."; return
        }
        message = ""
        let item = AVPlayer(url: url)
        player = item
        item.play()
    }
}

struct NativePlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        return controller
    }
    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        controller.player = player
    }
    static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: ()) {
        controller.player?.pause()
    }
}
