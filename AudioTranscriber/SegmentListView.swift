
import SwiftUI
import SwiftData

struct SegmentListView: View {
    @Bindable var session: RecordingSession

    var body: some View {
        List {
            ForEach(session.segments) { segment in
                VStack(alignment: .leading) {
                    Text("📄 \(URL(fileURLWithPath: segment.filePath).lastPathComponent)")
                        .bold()
                    Text("🗣️ \(segment.transcription ?? "Pending...")")
                        .foregroundColor(.gray)
                }
            }
        }
        .navigationTitle("Segments")
    }
}
