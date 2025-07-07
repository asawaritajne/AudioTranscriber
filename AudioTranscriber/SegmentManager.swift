import Foundation
import SwiftData

class SegmentManager {
    private var timer: Timer?
    private var segmentIndex = 0
    private let modelContext: ModelContext
    private var currentSession: RecordingSession
    
    init(context: ModelContext) {
        self.modelContext = context
        self.currentSession = RecordingSession(date: Date())
        modelContext.insert(currentSession)
    }
    
    func startSegmentTimer() {
        print("⏱️ Segment timer started.")
        self.timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task {
                await self.createSegment()
            }
        }
    }
    
    func stopSegmentTimer() {
        timer?.invalidate()
        timer = nil
        print("⛔ Segment timer stopped.")
    }
    
    private func createSegment() async {
        // ✅ Don't create segments if recording has stopped
        let isStillRecording = await MainActor.run {
            AudioRecorder.shared.isRecording
        }
        
        guard isStillRecording else {
            print("🛑 Skipped segment — recording has stopped.")
            return
        }
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "segment_\(timestamp).m4a"
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = dir.appendingPathComponent(fileName)
        
        guard let sourceURL = await MainActor.run { AudioRecorder.shared.file?.url },
        FileManager.default.fileExists(atPath: sourceURL.path) else {
            print("⚠️ Audio file not ready or does not exist yet.")
            return
        }
        
        do {
            try FileManager.default.copyItem(at: sourceURL, to: fileURL)
        } catch {
            print("⚠️ Failed to copy audio segment: \(error)")
            return
        }
        
        let segment = AudioSegment(filePath: fileURL.path)
        segment.session = currentSession
        modelContext.insert(segment)
        
        do {
            try modelContext.save()
        } catch {
            print("❌ Failed to save segment to context: \(error)")
        }
        
        if TranscriptionManager.shared.isConnected {
            TranscriptionManager.shared.transcribe(fileURL: fileURL, segment: segment)
        } else {
            TranscriptionManager.shared.queueOffline(segment: segment, fileURL: fileURL)
        }
        
        print("🎧 Segment saved at \(fileName)")
    }
}
