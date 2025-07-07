import SwiftUI
import SwiftData

struct SessionListView: View {
    @Query(sort: \RecordingSession.date, order: .reverse) var sessions: [RecordingSession]

    var body: some View {
        NavigationStack {
            List {
                ForEach(sessions) { session in
                    NavigationLink(destination: SegmentListView(session: session)) {
                        VStack(alignment: .leading) {
                            Text("📁 Session on \(session.date.formatted(.dateTime))")
                                .font(.headline)
                            Text("\(session.segments.count) segment(s)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("All Sessions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: LiveRecorderView()) {
                        Label("New", systemImage: "plus.circle.fill")
                    }
                }
            }

        }
    }
}
