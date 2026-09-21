import ScreenCaptureKit
import Testing
@testable import Scriber

struct CaptureStreamStopTests {
    private func error(_ code: SCStreamError.Code) -> NSError {
        NSError(domain: SCStreamErrorDomain, code: code.rawValue)
    }

    @Test func systemControlsStopTheEntireRecordingForEveryStream() {
        // macOS reports -3817 for each affected stream, including audio-only
        // streams. Reconnecting any one of them would undo the user's stop.
        for source in AudioSource.allCases {
            #expect(CaptureStreamStop.action(for: error(.userStopped), isVideo: false, audioSource: source) == .finish)
        }
        #expect(CaptureStreamStop.action(for: error(.userStopped), isVideo: true, audioSource: nil) == .finish)
    }

    @Test func retiredStreamCallbacksCannotEndOrRecoverTheCurrentRecording() {
        for code: SCStreamError.Code in [.userStopped, .internalError, .systemStoppedStream] {
            #expect(CaptureStreamStop.action(for: error(code), isVideo: false, audioSource: nil) == .ignore)
        }
    }

    @Test func realFailuresStillRecoverAudioOrReportVideoFailure() {
        for code: SCStreamError.Code in [.internalError, .systemStoppedStream, .userDeclined] {
            for source in AudioSource.allCases {
                #expect(CaptureStreamStop.action(for: error(code), isVideo: false, audioSource: source) == .recover(source))
            }
            #expect(CaptureStreamStop.action(for: error(code), isVideo: true, audioSource: nil) == .failVideo)
        }
        // A coincident error number from another domain is not a user stop.
        let unrelated = NSError(domain: NSCocoaErrorDomain, code: SCStreamError.Code.userStopped.rawValue)
        #expect(CaptureStreamStop.action(for: unrelated, isVideo: false, audioSource: .system) == .recover(.system))
        #expect(CaptureStreamStop.action(for: unrelated, isVideo: true, audioSource: nil) == .failVideo)
    }

    @Test func teardownToleratesOnlyTheAlreadyStoppedState() {
        // The observed user-stop event is followed by -3808 when stopCapture
        // runs during finalization. Other teardown failures must remain visible.
        #expect(CaptureStreamStop.isAlreadyStopped(error(.attemptToStopStreamState)))
        for code: SCStreamError.Code in [.userStopped, .failedToStopAudioCapture, .internalError, .userDeclined] {
            #expect(!CaptureStreamStop.isAlreadyStopped(error(code)))
        }
        let unrelated = NSError(domain: NSCocoaErrorDomain, code: SCStreamError.Code.attemptToStopStreamState.rawValue)
        #expect(!CaptureStreamStop.isAlreadyStopped(unrelated))
    }
}
