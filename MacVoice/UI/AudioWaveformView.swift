import SwiftUI

struct AudioWaveformView: View {
    let audioLevel: Float

    @State private var levels: [Float] = Array(repeating: -60, count: 40)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
            Canvas { context, size in
                let barCount = levels.count
                let spacing: CGFloat = 2
                let barWidth = (size.width - CGFloat(barCount - 1) * spacing) / CGFloat(barCount)
                let maxHeight = size.height

                for i in 0..<barCount {
                    let normalizedLevel = normalizeLevel(levels[i])
                    let barHeight = max(2, maxHeight * CGFloat(normalizedLevel))
                    let x = CGFloat(i) * (barWidth + spacing)
                    let y = (maxHeight - barHeight) / 2

                    let rect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
                    let path = Path(roundedRect: rect, cornerRadius: barWidth / 2)
                    context.fill(path, with: .color(.accentColor.opacity(0.7 + Double(normalizedLevel) * 0.3)))
                }
            }
            .onChange(of: audioLevel) { _, newLevel in
                levels.removeFirst()
                levels.append(newLevel)
            }
        }
    }

    private func normalizeLevel(_ db: Float) -> Float {
        // Map dB range (-60...0) to (0...1)
        let clamped = max(-60, min(0, db))
        return (clamped + 60) / 60
    }
}
