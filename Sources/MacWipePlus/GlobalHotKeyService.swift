import Carbon.HIToolbox

final class GlobalHotKeyService {
    private var hotKey: EventHotKeyRef?
    private var emergencyHotKey: EventHotKeyRef?
    private var fallbackEmergencyHotKey: EventHotKeyRef?
    private var simpleEmergencyHotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let onPress: () -> Void
    private let onEmergency: () -> Void
    private let signature: OSType = 0x4D575050

    init(onPress: @escaping () -> Void, onEmergency: @escaping () -> Void) {
        self.onPress = onPress
        self.onEmergency = onEmergency
    }

    func register(keyCode: UInt32, modifiers: UInt32) throws {
        unregister()
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                let service = Unmanaged<GlobalHotKeyService>.fromOpaque(userData).takeUnretainedValue()
                var hotKeyID = EventHotKeyID()
                let size = MemoryLayout<EventHotKeyID>.size
                let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, size, nil, &hotKeyID)
                guard status == noErr, hotKeyID.signature == service.signature else { return noErr }
                if hotKeyID.id == 2 || hotKeyID.id == 3 || hotKeyID.id == 4 {
                    service.onEmergency()
                } else {
                    service.onPress()
                }
                return noErr
            },
            1,
            &eventType,
            context,
            &handler
        )
        guard installStatus == noErr else { throw GlobalHotKeyError.registrationFailed(installStatus) }

        let identifier = EventHotKeyID(signature: signature, id: 1)
        let registerStatus = RegisterEventHotKey(keyCode, modifiers, identifier, GetApplicationEventTarget(), 0, &hotKey)
        guard registerStatus == noErr else {
            RemoveEventHandler(handler!)
            handler = nil
            throw GlobalHotKeyError.registrationFailed(registerStatus)
        }

        let emergencyIdentifier = EventHotKeyID(signature: signature, id: 2)
        let emergencyModifiers = UInt32(optionKey | cmdKey)
        let emergencyStatus = RegisterEventHotKey(53, emergencyModifiers, emergencyIdentifier, GetApplicationEventTarget(), 0, &emergencyHotKey)
        if emergencyStatus != noErr {
            emergencyHotKey = nil
        }
        let fallbackEmergencyIdentifier = EventHotKeyID(signature: signature, id: 3)
        let fallbackEmergencyModifiers = UInt32(controlKey | optionKey | cmdKey)
        let fallbackEmergencyStatus = RegisterEventHotKey(53, fallbackEmergencyModifiers, fallbackEmergencyIdentifier, GetApplicationEventTarget(), 0, &fallbackEmergencyHotKey)
        if fallbackEmergencyStatus != noErr {
            fallbackEmergencyHotKey = nil
        }
        let simpleEmergencyIdentifier = EventHotKeyID(signature: signature, id: 4)
        let simpleEmergencyModifiers = UInt32(controlKey | optionKey)
        let simpleEmergencyStatus = RegisterEventHotKey(53, simpleEmergencyModifiers, simpleEmergencyIdentifier, GetApplicationEventTarget(), 0, &simpleEmergencyHotKey)
        if simpleEmergencyStatus != noErr {
            simpleEmergencyHotKey = nil
        }
    }

    func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
        if let emergencyHotKey { UnregisterEventHotKey(emergencyHotKey) }
        emergencyHotKey = nil
        if let fallbackEmergencyHotKey { UnregisterEventHotKey(fallbackEmergencyHotKey) }
        fallbackEmergencyHotKey = nil
        if let simpleEmergencyHotKey { UnregisterEventHotKey(simpleEmergencyHotKey) }
        simpleEmergencyHotKey = nil
        if let handler { RemoveEventHandler(handler) }
        handler = nil
    }

    deinit { unregister() }
}

enum GlobalHotKeyError: Error {
    case registrationFailed(OSStatus)
}
