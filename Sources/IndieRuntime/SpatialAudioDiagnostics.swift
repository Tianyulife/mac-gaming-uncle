public enum SpatialAudioDiagnostics {
    public static func environment(enabled: Bool) -> [String: String] {
        enabled ? [
            "WINEDEBUG": "-all,+mmdevapi,+coreaudio",
            "SWITCHYARD_SPATIAL_AUDIO_PROFILE": "1",
        ] : [:]
    }
}
