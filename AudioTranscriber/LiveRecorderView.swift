import SwiftUI
import SwiftData

struct LiveRecorderView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var recorder = AudioRecorder.shared
    @State private var segmentManager: SegmentManager?
    @State private var savedFileName: String?

    var body: some View {
        VStack(spacing: 30) {
            Text("Live Recorder")
                .font(.largeTitle)
                .bold()

            Image(systemName: recorder.isRecording ? "mic.fill" : "mic.slash")
                .resizable()
                .frame(width: 50, height: 50)
                .foregroundColor(recorder.isRecording ? .red : .gray)

            Button(action: {
                if recorder.isRecording {
                    recorder.stopRecording { url in
                        if let url { savedFileName = url.lastPathComponent }
                        segmentManager?.stopSegmentTimer()
                    }
                } else {
                    recorder.startRecording()
                    let manager = SegmentManager(context: modelContext)
                    segmentManager = manager
                    manager.startSegmentTimer()
                }
            }) {
                Text(recorder.isRecording ? "Stop Recording" : "Start Recording")
                    .font(.title2)
                    .padding()
                    .background(recorder.isRecording ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }

            if let savedFileName {
                Text("Saved file: \(savedFileName)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("New Recording")
        .navigationBarTitleDisplayMode(.inline)
    }
}
