import AVFoundation
import CoreAudio
import os

extension AVAudioInputNode {
    private static let logger = Logger(subsystem: "com.macvoice.app", category: "audio")

    func applyPreferredInputDevice(uid: String) {
        guard let deviceID = audioDeviceID(forUID: uid) else {
            Self.logger.warning("Selected microphone not found for uid=\(uid, privacy: .public)")
            return
        }

        guard let audioUnit = self.audioUnit else {
            Self.logger.error("Input audio unit unavailable; cannot set preferred microphone")
            return
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
        } else {
            Self.logger.info("Using preferred microphone uid=\(uid, privacy: .public)")
        }
    }

    private func audioDeviceID(forUID uid: String) -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var size: UInt32 = 0
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size)
        let deviceCount = Int(size) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: deviceCount)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &devices)

        for device in devices {
            var uidString: CFString? = nil
            var uidSize = UInt32(MemoryLayout<CFString?>.size)
            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            let status = AudioObjectGetPropertyData(device, &uidAddress, 0, nil, &uidSize, &uidString)
            if status == noErr, let currentUID = uidString as String?, currentUID == uid {
                return device
            }
        }
        return nil
    }
}
