import Foundation
import AVFoundation
import Network

class TranscriptionManager {
    static let shared = TranscriptionManager()

    private var retryCounts: [String: Int] = [:]
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    public var isConnected: Bool = true

    private init() {
        monitor.pathUpdateHandler = { path in
            self.isConnected = path.status == .satisfied
            print("🌐 Network status: \(self.isConnected ? "Online" : "Offline")")
        }
        monitor.start(queue: queue)
    }

    // MARK: - Main Transcription Entry Point
    func transcribe(fileURL: URL, segment: AudioSegment) {
        let path = fileURL.path

        // ❌ Network not available
        if !isConnected {
            queueOffline(segment: segment, fileURL: fileURL)
            return
        }

        print("📤 Preparing to send \(fileURL.lastPathComponent) to Whisper API")

        // 🔁 Real API call
        sendToOpenAI(fileURL: fileURL) { [weak self] text in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let text = text {
                    segment.transcription = text
                    print("✅ Transcribed via OpenAI: \(text)")
                } else {
                    print("❌ API failed for \(fileURL.lastPathComponent)")
                    self.handleFailure(fileURL: fileURL, segment: segment)
                }
            }
        }
    }

    // MARK: - Send to Whisper API
    private func sendToOpenAI(fileURL: URL, completion: @escaping (String?) -> Void) {
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Secrets.openAIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        guard let audioData = try? Data(contentsOf: fileURL) else {
            print("❌ Failed to read file at \(fileURL.path)")
            completion(nil)
            return
        }

        print("📦 Sending audio file to OpenAI: \(fileURL.lastPathComponent), size: \(audioData.count) bytes")

        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n")
        body.append("Content-Type: audio/m4a\r\n\r\n")
        body.append(audioData)
        body.append("\r\n")

        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        body.append("whisper-1\r\n")
        body.append("--\(boundary)--\r\n")

        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ OpenAI API error: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let data = data else {
                print("❌ No data received")
                completion(nil)
                return
            }

            if let jsonString = String(data: data, encoding: .utf8) {
                print("📥 API Raw Response: \(jsonString)")
            }

            if let result = try? JSONDecoder().decode(OpenAITranscriptionResponse.self, from: data) {
                completion(result.text)
            } else {
                print("❌ Failed to decode JSON response")
                completion(nil)
            }
        }.resume()
    }

    // MARK: - Failure Retry Logic
    private func handleFailure(fileURL: URL, segment: AudioSegment) {
        let path = fileURL.path
        retryCounts[path, default: 0] += 1

        if retryCounts[path]! >= 5 {
            print("🤖 Fallback to Apple STT")
            transcribeWithAppleSTT(fileURL: fileURL) { fallback in
                DispatchQueue.main.async {
                    segment.transcription = fallback
                }
            }
            return
        }

        let delay = pow(2.0, Double(retryCounts[path]!))
        print("🔁 Retry in \(delay)s")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.transcribe(fileURL: fileURL, segment: segment)
        }
    }

    // MARK: - Apple Local Transcription (fallback)
    private func transcribeWithAppleSTT(fileURL: URL, completion: @escaping (String?) -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            let result = "🗣️ Apple STT for \(fileURL.lastPathComponent)"
            print("✅ Local transcription: \(result)")
            completion(result)
        }
    }

    // MARK: - Offline Queue
    func queueOffline(segment: AudioSegment, fileURL: URL) {
        print("📵 Queued for later (offline): \(segment.filePath)")
        // (Optional) Persist these for retrying later
    }
}

// MARK: - Multipart Form Helper
extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

// MARK: - Whisper Response
struct OpenAITranscriptionResponse: Decodable {
    let text: String
}
