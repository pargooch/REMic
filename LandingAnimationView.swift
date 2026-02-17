import SwiftUI
import AVKit

// MARK: - Landing Animation View

struct LandingAnimationView: View {
    let onFinished: () -> Void

    @State private var player: AVPlayer?
    @State private var playerDidFinish = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                VideoPlayerView(player: player)
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func setupPlayer() {
        guard let url = Bundle.main.url(forResource: "landing-animation", withExtension: "mp4") else {
            // Video not found, skip animation
            onFinished()
            return
        }

        let avPlayer = AVPlayer(url: url)
        avPlayer.actionAtItemEnd = .none

        // Observe when video finishes
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: avPlayer.currentItem,
            queue: .main
        ) { _ in
            guard !playerDidFinish else { return }
            playerDidFinish = true
            onFinished()
        }

        self.player = avPlayer
        avPlayer.play()
    }
}

// MARK: - Video Player (UIViewRepresentable)

/// AVPlayerLayer wrapper that center-crops the video to fill the view
private struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }
}

private class PlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}
