import Foundation
import AVFoundation
import os

class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var recordingURL: URL?
    @Published var audioLevel: Float = 0.0

    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?

    override init() {
        super.init()
    }

    func startRecording() {
        Logger.audio.info("Initiating recording flow...")
        let recordingSession = AVAudioSession.sharedInstance()

        do {
            // Configure for background audio recording
            try recordingSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.allowBluetoothHFP, .defaultToSpeaker]
            )
            try recordingSession.setActive(true, options: .notifyOthersOnDeactivation)

            let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            // Change extension to .wav
            let audioFilename = docDir.appendingPathComponent("recording.wav")
            Logger.audio.debug("Recording path: \(audioFilename.path)")

            // Switch to LinearPCM (WAV) which is safer for WhisperKit
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 16000, // 16kHz is ideal for Whisper
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsFloatKey: false // Signed Integer PCM
            ]

            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()

            isRecording = true
            recordingURL = nil

            startMonitoring()
            Logger.audio.notice("Recording started (WAV 16kHz).")

        } catch {
            Logger.audio.error("Failed to start recording: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        Logger.audio.info("Stopping recording...")
        audioRecorder?.stop()
        isRecording = false
        stopMonitoring()
        recordingURL = audioRecorder?.url

        if let url = recordingURL {
            do {
                let resources = try url.resourceValues(forKeys: [.fileSizeKey])
                let fileSize = resources.fileSize ?? 0
                Logger.audio.notice("Recording stopped. File saved. Size: \(fileSize) bytes")
            } catch {
                Logger.audio.error("Could not determine file size.")
            }
        }
    }

    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.audioRecorder?.updateMeters()
            self.audioLevel = self.audioRecorder?.averagePower(forChannel: 0) ?? -160.0
        }
    }

    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        audioLevel = 0.0
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            Logger.audio.error("Audio Recorder finish flag is false.")
            recordingURL = nil
        } else {
            Logger.audio.info("Audio Recorder finished successfully.")
        }
    }
}
