import AVFoundation
import CoreAudio
import os

extension AVAudioInputNode {
    private static let logger = Logger(subsystem: "com.macvoice.app", category: "audio")

    @discardableResult
    func applyPreferredInputDevice(uid: String) -> Bool {
        guard let deviceID = audioDeviceID(forUID: uid) else {
            Self.logger.warning("Selected microphone not found for uid=\(uid, privacy: .public)")
            return false
        }

        guard let audioUnit = self.audioUnit else {
            Self.logger.error("Input audio unit unavailable; cannot set preferred microphone")
            return false
        }

        var mutableID = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &mutableID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )

        if status != noErr {
            Self.logger.error("Failed to set preferred microphone (status=\(status, privacy: .public))")
            return false
        } else {
            Self.logger.info("Using preferred microphone uid=\(uid, privacy: .public)")
            return true
        }
    }

    private func audioDeviceID(forUID uid: String) -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslateUIDToDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var uidString: CFString = uid as CFString
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            UInt32(MemoryLayout<CFString>.size),
            &uidString,
            &size,
            &deviceID
        )

        guard status == noErr, deviceID != 0 else { return nil }
        return deviceID
    }
}
