import SwiftUI

private enum WaveformStyle {
    static let mainSamplePitch: CGFloat = 2.15
    static let mainBarWidth: CGFloat = 1
    static let mainMinBarHeight: CGFloat = 0.5
    static let miniSamplePitch: CGFloat = 1.15
    static let miniBarWidth: CGFloat = 1
    static let miniMinBarHeight: CGFloat = 0.35
    static let playheadColor = Color(red: 1.0, green: 0.27, blue: 0.22)
    static let axisColor = Color.white.opacity(0.28)
    static let axisTickColor = Color.white.opacity(0.1)
    static let recordingBarColor = Color(red: 1.0, green: 0.27, blue: 0.22)
    static let miniBarColor = Color(red: 1.0, green: 0.27, blue: 0.22)
    static let miniCursorColor = Color(red: 1.0, green: 0.27, blue: 0.22)
}

private func compressedWaveformSamples(_ samples: [Float], targetCount: Int) -> [Float] {
    guard targetCount > 0, !samples.isEmpty else { return [] }
    guard samples.count > targetCount else { return samples }

    let bucketSize = Double(samples.count) / Double(targetCount)
    return (0..<targetCount).map { bucketIndex in
        let start = Int((Double(bucketIndex) * bucketSize).rounded(.down))
        let end = min(samples.count, Int((Double(bucketIndex + 1) * bucketSize).rounded(.up)))
        guard start < end else { return 0 }

        var peak: Float = 0
        var sum: Float = 0
        for sample in samples[start..<end] {
            peak = max(peak, sample)
            sum += sample
        }
        let average = sum / Float(end - start)
        return max(peak * 0.65, average)
    }
}

private func waveformBarPath(
    in rect: CGRect,
    samples: [Float],
    samplePitch: CGFloat,
    barWidth: CGFloat,
    minBarHeight: CGFloat,
    maxBarHeight: CGFloat,
    alignsToTrailingEdge: Bool = true
) -> Path {
    var path = Path()
    guard !samples.isEmpty else { return path }

    let startX: CGFloat
    if alignsToTrailingEdge {
        startX = rect.maxX - CGFloat(max(samples.count - 1, 0)) * samplePitch
    } else {
        startX = rect.minX
    }

    for (index, sample) in samples.enumerated() {
        let x = startX + CGFloat(index) * samplePitch
        let amplitude = CGFloat(max(0, min(1, sample)))
        let easedAmplitude = pow(amplitude, 1.18)
        let barHeight = min(maxBarHeight, max(minBarHeight, easedAmplitude * maxBarHeight))
        let barRect = CGRect(
            x: x - (barWidth / 2),
            y: rect.midY - (barHeight / 2),
            width: barWidth,
            height: barHeight
        )
        path.addRect(barRect)
    }

    return path
}

private func timeLabel(for seconds: Int) -> String {
    String(format: "%d:%02d", seconds / 60, seconds % 60)
}

struct AudioWaveformView: View {
    let audioRecorder: AudioRecorder

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let elapsed = max(0, timeline.date.timeIntervalSince(audioRecorder.recordingStartDate))
            GeometryReader { geo in
                let size = geo.size
                let visibleCount = max(16, Int((size.width * 0.62) / WaveformStyle.mainSamplePitch) + 2)
                let visibleSamples = Array(audioRecorder.waveformSamples.suffix(visibleCount))

                ZStack(alignment: .bottom) {
                    Canvas { context, canvasSize in
                        drawWaveform(context: &context, size: canvasSize, samples: visibleSamples)
                    }
                    .padding(.bottom, 22)

                    playhead(height: size.height)

                    timeAxisCanvas(width: size.width, elapsed: elapsed)
                        .frame(height: 22)
                }
            }
        }
        .clipped()
    }

    private func drawWaveform(context: inout GraphicsContext, size: CGSize, samples: [Float]) {
        let playheadX = size.width / 2
        let visibleWidth = CGFloat(max(samples.count - 1, 1)) * WaveformStyle.mainSamplePitch
        let startX = max(0, playheadX - visibleWidth)
        let waveRect = CGRect(x: startX, y: 4, width: playheadX - startX, height: max(1, size.height - 26))
        let bars = waveformBarPath(
            in: waveRect,
            samples: samples,
            samplePitch: WaveformStyle.mainSamplePitch,
            barWidth: WaveformStyle.mainBarWidth,
            minBarHeight: WaveformStyle.mainMinBarHeight,
            maxBarHeight: waveRect.height * 0.72
        )

        context.fill(bars, with: .color(WaveformStyle.recordingBarColor))
    }

    private func playhead(height: CGFloat) -> some View {
        GeometryReader { geo in
            let midX = geo.size.width / 2
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: midX, y: 0))
                    path.addLine(to: CGPoint(x: midX, y: geo.size.height - 22))
                }
                .stroke(WaveformStyle.playheadColor, lineWidth: 1)

                Circle()
                    .fill(WaveformStyle.playheadColor)
                    .frame(width: 7, height: 7)
                    .position(x: midX, y: geo.size.height - 20)
            }
        }
    }

    private func timeAxisCanvas(width: CGFloat, elapsed: TimeInterval) -> some View {
        Canvas { context, size in
            let playheadX = size.width / 2
            let pxPerSec = WaveformStyle.mainSamplePitch / max(audioRecorder.waveformSampleInterval, 0.001)
            let newestWholeSecond = Int(elapsed.rounded(.down))
            let oldestWholeSecond = max(0, newestWholeSecond - 8)

            for second in oldestWholeSecond...newestWholeSecond {
                let x = playheadX - CGFloat(elapsed - Double(second)) * pxPerSec
                guard x >= -24, x <= size.width + 24 else { continue }

                var tickPath = Path()
                tickPath.move(to: CGPoint(x: x, y: 1))
                tickPath.addLine(to: CGPoint(x: x, y: 6))
                context.stroke(tickPath, with: .color(WaveformStyle.axisTickColor), lineWidth: 1)

                let label = Text(timeLabel(for: second))
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundStyle(WaveformStyle.axisColor)
                context.draw(context.resolve(label), at: CGPoint(x: x, y: 15), anchor: .center)
            }
        }
    }
}

struct MiniWaveformBar: View {
    let audioRecorder: AudioRecorder

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let visibleCount = max(8, Int((size.width - 10) / WaveformStyle.miniSamplePitch) + 2)
            let visibleSamples = compressedWaveformSamples(audioRecorder.waveformSamples, targetCount: visibleCount)

            ZStack(alignment: .trailing) {
                Canvas { context, canvasSize in
                    let rect = CGRect(x: 5, y: 4, width: max(1, canvasSize.width - 10), height: max(1, canvasSize.height - 8))
                    let bars = waveformBarPath(
                        in: rect,
                        samples: visibleSamples,
                        samplePitch: WaveformStyle.miniSamplePitch,
                        barWidth: WaveformStyle.miniBarWidth,
                        minBarHeight: WaveformStyle.miniMinBarHeight,
                        maxBarHeight: rect.height * 0.9,
                        alignsToTrailingEdge: false
                    )
                    context.fill(bars, with: .color(WaveformStyle.miniBarColor))
                }

                RoundedRectangle(cornerRadius: 1.25)
                    .fill(WaveformStyle.miniCursorColor)
                    .frame(width: 4, height: max(14, size.height - 6))
                    .padding(.trailing, 1)
            }
        }
    }
}

struct RecordingTimeCounter: View {
    let audioRecorder: AudioRecorder

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let elapsed = audioRecorder.isRecording
                ? max(0, timeline.date.timeIntervalSince(audioRecorder.recordingStartDate))
                : 0
            Text(formatElapsed(elapsed))
                .monospacedDigit()
        }
    }

    private func formatElapsed(_ t: TimeInterval) -> String {
        let totalCentiseconds = Int(t * 100)
        let minutes = totalCentiseconds / 6000
        let seconds = (totalCentiseconds % 6000) / 100
        let centis = totalCentiseconds % 100
        return String(format: "%02d:%02d,%02d", minutes, seconds, centis)
    }
}
