import ScreenCaptureKit

/// A stop from the macOS capture controls ends the whole recording. It is not
/// a device outage and must never feed the audio reconnection loop.
enum CaptureStreamStop: Equatable {
    case ignore
    case finish
    case failVideo
    case recover(AudioSource)

    static func action(for error: any Error, isVideo: Bool, audioSource: AudioSource?) -> Self {
        // Late callbacks from retired/replaced streams must not stop a new one.
        guard isVideo || audioSource != nil else { return .ignore }
        let error = error as NSError
        if error.domain == SCStreamErrorDomain, error.code == SCStreamError.Code.userStopped.rawValue {
            return .finish
        }
        if isVideo { return .failVideo }
        if let audioSource { return .recover(audioSource) }
        return .ignore
    }

    static func isAlreadyStopped(_ error: any Error) -> Bool {
        let error = error as NSError
        return error.domain == SCStreamErrorDomain
            && error.code == SCStreamError.Code.attemptToStopStreamState.rawValue
    }
}
