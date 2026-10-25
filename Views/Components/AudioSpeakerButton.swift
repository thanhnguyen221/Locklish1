import SwiftUI

// MARK: - AudioSpeakerButton
/// Interactive speaker button with animated wave pulses and haptic feedback.
struct AudioSpeakerButton: View {
    let word: String
    var size: CGFloat = 44
    var iconSize: CGFloat = 18
    var tintColor: Color = AppTheme.primary
    var onTap: (() -> Void)? = nil  // Optional callback when button is tapped

    @State private var tts = TTSService.shared
    @State private var isPulsing = false

    private var isCurrentlySpeakingThisWord: Bool {
        tts.isSpeaking && tts.currentWord == word
    }

    // Global timestamp tracking the last time any speaker was tapped
    // Ancestor views can check this to avoid triggering card flip gestures
    static var lastTapTime: Date = .distantPast

    private func triggerAudio() {
        AudioSpeakerButton.lastTapTime = Date()
        HapticFeedback.light()
        tts.speak(text: word)
        onTap?()
    }

    var body: some View {
        Button(action: {
            triggerAudio()
        }) {
            ZStack {
                // Pulse ripple effect when speaking
                if isCurrentlySpeakingThisWord {
                    Circle()
                        .stroke(tintColor.opacity(0.3), lineWidth: 2)
                        .scaleEffect(isPulsing ? 1.35 : 1.0)
                        .opacity(isPulsing ? 0.0 : 0.8)
                        .animation(.easeOut(duration: 0.9).repeatForever(autoreverses: false), value: isPulsing)
                }

                Circle()
                    .fill(tintColor.opacity(0.12))
                    .frame(width: size, height: size)

                Image(systemName: isCurrentlySpeakingThisWord ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(tintColor)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .highPriorityGesture(
            TapGesture().onEnded {
                triggerAudio()
            }
        )
        .accessibilityLabel("Nghe phát âm từ \(word)")
        .onChange(of: isCurrentlySpeakingThisWord) { _, isSpeaking in
            isPulsing = isSpeaking
        }
    }
}

#Preview {
    AudioSpeakerButton(word: "Schedule")
        .padding()
}
