import Foundation
import AudioToolbox

/// Optional terminal-style sound effects for key events.
///
/// Uses lightweight system sounds via `AudioToolbox` (no audio session setup or
/// bundled assets required). Every call respects the `soundEnabled` AppStorage
/// flag and no-ops when disabled.
final class SoundManager {
    static let shared = SoundManager()

    enum Effect {
        case scanStart
        case scanComplete
        case criticalFinding

        /// Matching iOS system sound IDs.
        var systemSoundID: SystemSoundID {
            switch self {
            case .scanStart:       return 1057 // short "boot up" blip (Tink)
            case .scanComplete:    return 1001 // success chime (mail-sent)
            case .criticalFinding: return 1006 // alert buzz
            }
        }
    }

    private init() {}

    private var soundEnabled: Bool {
        // Default ON when never set, matching the Settings toggle's default.
        UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
    }

    func play(_ effect: Effect) {
        guard soundEnabled else { return }
        AudioServicesPlaySystemSound(effect.systemSoundID)
    }
}
