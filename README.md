# AudioTranscriber

AudioTranscriber is a macOS/iOS app that records audio and transcribes it using OpenAI's Whisper API.

Features

- Record audio
- Transcribe using OpenAI Whisper
- Built in Swift
- Simple UI

 Requirements

- Xcode
- Swift 5+
- macOS or iOS
- OpenAI API key

Setup Instructions

AudioTranscriber - Setup Instructions
1. Clone the repository
Open your terminal and run:
git clone https://github.com/asawaritajne/AudioTranscriber.git
2. Open the project in Xcode
Navigate to the cloned folder and open the `.xcodeproj` file.
3. Create a Secrets.swift file
Inside the AudioTranscriber/ folder of your project, create a new Swift file named Secrets.swift.
4. Add your OpenAI API key
Paste the following into the file:
let openAIKey = "YOUR_API_KEY_HERE"
Note: Do not share your actual API key. This file is ignored by Git using .gitignore.
5. Install dependencies (if any)
No external Swift packages are required, but ensure you are running the project with the latest
version of Xcode.
6. Build and run the app
- Select a target simulator or connect your iOS device.
- Press Cmd + R to build and run.
- Use the interface to record audio and see transcribed results.
