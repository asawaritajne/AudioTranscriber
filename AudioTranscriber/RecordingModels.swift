import Foundation
import SwiftData

enum TranscriptionStatus: String, Codable {
    case pending, completed, failed
}

@Model
class RecordingSession {
    var id = UUID()
    var date: Date
    @Relationship(deleteRule: .cascade) var segments: [AudioSegment] = []

    init(date: Date = .now) {
        self.date = date
    }
}

@Model
class AudioSegment {
    var id = UUID()
    var filePath: String
    var transcription: String?
    var status: TranscriptionStatus
    var retries: Int = 0

    @Relationship var session: RecordingSession?

    init(filePath: String, transcription: String? = nil, status: TranscriptionStatus = .pending) {
        self.filePath = filePath
        self.transcription = transcription
        self.status = status
    }
}
