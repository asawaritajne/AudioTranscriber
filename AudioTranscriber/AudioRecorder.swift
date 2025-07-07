import Foundation
import AVFoundation
import Combine

@MainActor
class AudioRecorder: NSObject, ObservableObject {
    static let shared = AudioRecorder()
    
    private let engine = AVAudioEngine()
    private let session = AVAudioSession.sharedInstance()
    
    public var file: AVAudioFile?
    public private(set) var currentFileURL: URL?
    
    @Published var isRecording = false
    @Published var transcriptionText: String?

    override init() {
        super.init()
        setupNotifications()
    }

    func startRecording() {
        Task {
            let granted = await AVAudioApplication.requestRecordPermission()
            if granted {
                print("🎤 Microphone permission granted.")
            } else {
                print("🚫 Microphone permission denied.")
                return
            }

            do {
                try configureSession()
                try session.setActive(true, options: [.notifyOthersOnDeactivation])

                let input = engine.inputNode
                let format = input.outputFormat(forBus: 0)

                let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileName = "recording_\(Date().timeIntervalSince1970).caf"
                let fileURL = dir.appendingPathComponent(fileName)

                file = try AVAudioFile(forWriting: fileURL, settings: format.settings)
                self.currentFileURL = fileURL

                input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                    do {
                        try self.file?.write(from: buffer)
                    } catch {
                        print("❌ Failed writing buffer: \(error)")
                    }
                }

                engine.prepare()
                try engine.start()
                isRecording = true
                print("🎙️ Recording started at: \(fileURL.path)")

            } catch {
                print("❌ Error starting recording: \(error)")
            }
        }
    }

    func stopRecording(completion: @escaping (URL?) -> Void) {
        guard isRecording else {
            print("⚠️ Tried to stop recording, but no active recording.")
            completion(nil)
            return
        }

        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        isRecording = false

        if let file = file {
            print("✅ Audio saved to: \(file.url.path)")
            self.transcribeAudioFile(url: file.url)
            completion(file.url)
        } else {
            print("⚠️ No audio file available.")
            completion(nil)
        }
    }

    // MARK: - Transcription via Whisper API (Streaming Upload)

    private func transcribeAudioFile(url: URL) {
        Task {
            let apiKey = "Secrets.openAIKey" 
            let endpoint = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            let boundary = UUID().uuidString
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            // Create a temp file to stream the multipart request
            let tempBodyURL = FileManager.default.temporaryDirectory.appendingPathComponent("whisper_upload_body.txt")
            guard let outputStream = OutputStream(url: tempBodyURL, append: false) else {
                print("❌ Failed to create output stream.")
                return
            }

            outputStream.open()

            func write(_ string: String) {
                let data = string.data(using: .utf8)!
                _ = data.withUnsafeBytes {
                    outputStream.write($0.bindMemory(to: UInt8.self).baseAddress!, maxLength: data.count)
                }
            }

            write("--\(boundary)\r\n")
            write("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
            write("whisper-1\r\n")

            write("--\(boundary)\r\n")
            write("Content-Disposition: form-data; name=\"file\"; filename=\"\(url.lastPathComponent)\"\r\n")
            write("Content-Type: audio/wav\r\n\r\n")

            if let audioData = try? Data(contentsOf: url) {
                _ = audioData.withUnsafeBytes {
                    outputStream.write($0.bindMemory(to: UInt8.self).baseAddress!, maxLength: audioData.count)
                }
            } else {
                print("❌ Failed to read audio file.")
                outputStream.close()
                return
            }

            write("\r\n--\(boundary)--\r\n")
            outputStream.close()

            do {
                let (responseData, _) = try await URLSession.shared.upload(for: request, fromFile: tempBodyURL)
                if let json = try? JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any],
                   let text = json["text"] as? String {
                    print("📝 Transcription: \(text)")
                    self.transcriptionText = text
                } else {
                    print("⚠️ Failed to parse transcription.")
                }
            } catch {
                print("❌ Transcription failed: \(error)")
            }
        }
    }

    // MARK: - Session Setup

    private func configureSession() throws {
        try session.setCategory(.playAndRecord,
                                mode: .default,
                                options: [.defaultToSpeaker, .allowBluetooth])
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleRouteChange),
                                               name: AVAudioSession.routeChangeNotification,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleInterruption),
                                               name: AVAudioSession.interruptionNotification,
                                               object: nil)
    }

    // MARK: - Route Change

    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        switch reason {
        case .oldDeviceUnavailable:
            print("🎧 Headphones unplugged.")
        case .newDeviceAvailable:
            print("🎧 New audio device plugged in.")
        default:
            break
        }
    }

    // MARK: - Interruption Handling

    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        if type == .began {
            print("☎️ Interruption began. Pausing engine...")
            engine.pause()
        } else if type == .ended {
            do {
                try session.setActive(true)
                try engine.start()
                print("📞 Interruption ended. Resumed recording.")
            } catch {
                print("❌ Failed to resume after interruption: \(error)")
            }
        }
    }
}
