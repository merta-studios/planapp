import Foundation
import Combine
import CoreBluetooth

/// Liest den tatsächlichen GATT-Batteriewert eines bereits mit iPadOS
/// verbundenen Apple Pencil aus. Es wird weder nach fremden Geräten gescannt
/// noch ein anderer Akkuwert als Pencil-Akku ausgegeben.
final class ApplePencilBatteryMonitor: NSObject, ObservableObject {
    enum Status: Equatable {
        case idle
        case searching
        case connecting
        case reading
        case available
        case unavailable
        case bluetoothUnavailable
    }

    @Published private(set) var batteryLevel: Int?
    @Published private(set) var pencilName: String? = nil
    @Published private(set) var status: Status = .idle

    private static let batteryService = CBUUID(string: "180F")
    private static let batteryLevelCharacteristic = CBUUID(string: "2A19")
    private static let deviceInformationService = CBUUID(string: "180A")

    private var centralManager: CBCentralManager?
    private var pencilPeripheral: CBPeripheral?
    private var batteryCharacteristic: CBCharacteristic?
    private var monitoringRequested = false
    private var isConnecting = false
    private var pendingCharacteristicServices = 0
    private var lastSearchDate = Date.distantPast
    private var attemptTimeout: DispatchWorkItem?

    override init() {
        super.init()
        centralManager = CBCentralManager(
            delegate: self,
            queue: .main,
            options: [CBCentralManagerOptionShowPowerAlertKey: false]
        )
    }

    /// Wird erst nach tatsächlich beobachtetem Apple-Pencil-Input aufgerufen,
    /// damit die Bluetooth-Berechtigungsabfrage nicht beim App-Start erscheint.
    func startMonitoring() {
        monitoringRequested = true
        guard let centralManager else { return }

        if centralManager.state == .poweredOn {
            beginSearch()
        } else if centralManager.state == .poweredOff
                    || centralManager.state == .unauthorized
                    || centralManager.state == .unsupported {
            status = .bluetoothUnavailable
        }
    }

    private func beginSearch() {
        guard let centralManager,
              centralManager.state == .poweredOn,
              !isConnecting,
              pencilPeripheral == nil,
              Date().timeIntervalSince(lastSearchDate) >= 10 else { return }

        lastSearchDate = Date()
        status = .searching

        // Nur bereits mit iPadOS verbundene Geräte berücksichtigen. Ein
        // ungebundenes Scannen könnte versehentlich den Pencil einer anderen
        // Person in der Nähe erwischen und dessen Ladestand anzeigen.
        let connectedPeripherals = centralManager.retrieveConnectedPeripherals(
            withServices: [Self.batteryService, Self.deviceInformationService]
        )
        guard let pencil = connectedPeripherals.first(where: { Self.isApplePencil($0.name) }) else {
            status = .unavailable
            return
        }

        connect(to: pencil)
    }

    private func connect(to peripheral: CBPeripheral) {
        guard let centralManager else { return }
        pencilPeripheral = peripheral
        batteryCharacteristic = nil
        if let name = peripheral.name, !name.isEmpty {
            pencilName = name
        }
        peripheral.delegate = self
        isConnecting = true
        status = .connecting
        scheduleAttemptTimeout()
        centralManager.connect(peripheral, options: nil)
    }

    private func scheduleAttemptTimeout() {
        attemptTimeout?.cancel()
        let timeout = DispatchWorkItem { [weak self] in
            guard let self, self.batteryLevel == nil else { return }
            self.finishUnavailable(disconnect: true)
        }
        attemptTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: timeout)
    }

    private func finishUnavailable(disconnect: Bool) {
        attemptTimeout?.cancel()
        attemptTimeout = nil
        isConnecting = false
        pendingCharacteristicServices = 0

        if disconnect, let pencilPeripheral {
            centralManager?.cancelPeripheralConnection(pencilPeripheral)
        }
        pencilPeripheral = nil
        batteryCharacteristic = nil
        status = batteryLevel == nil ? .unavailable : .available
    }

    private static func isApplePencil(_ name: String?) -> Bool {
        guard let name else { return false }
        return name.localizedCaseInsensitiveContains("Apple Pencil")
    }

    private func acceptBatteryValue(_ data: Data) {
        guard let rawValue = data.first, rawValue <= 100 else { return }
        attemptTimeout?.cancel()
        attemptTimeout = nil
        batteryLevel = Int(rawValue)
        status = .available
    }
}

extension ApplePencilBatteryMonitor: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if monitoringRequested { beginSearch() }
        case .poweredOff, .unauthorized, .unsupported:
            attemptTimeout?.cancel()
            attemptTimeout = nil
            isConnecting = false
            pendingCharacteristicServices = 0
            pencilPeripheral = nil
            batteryCharacteristic = nil
            status = .bluetoothUnavailable
        case .resetting, .unknown:
            break
        @unknown default:
            status = .bluetoothUnavailable
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard peripheral === pencilPeripheral else { return }
        isConnecting = false
        status = .reading
        // Discover the accessible GATT profile and look for the standard
        // Battery Level characteristic (2A19), including vendor service layouts.
        peripheral.discoverServices(nil)
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        guard peripheral === pencilPeripheral else { return }
        finishUnavailable(disconnect: false)
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        guard peripheral === pencilPeripheral else { return }
        attemptTimeout?.cancel()
        attemptTimeout = nil
        pencilPeripheral = nil
        batteryCharacteristic = nil
        isConnecting = false
        status = batteryLevel == nil ? .unavailable : .available
    }
}

extension ApplePencilBatteryMonitor: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard peripheral === pencilPeripheral else { return }
        guard error == nil, let services = peripheral.services, !services.isEmpty else {
            finishUnavailable(disconnect: true)
            return
        }

        pendingCharacteristicServices = services.count
        for service in services {
            peripheral.discoverCharacteristics([Self.batteryLevelCharacteristic], for: service)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard peripheral === pencilPeripheral else { return }
        defer {
            pendingCharacteristicServices = max(0, pendingCharacteristicServices - 1)
            if pendingCharacteristicServices == 0, batteryCharacteristic == nil {
                finishUnavailable(disconnect: true)
            }
        }
        guard error == nil,
              let characteristic = service.characteristics?.first(where: {
                  $0.uuid == Self.batteryLevelCharacteristic
              }) else { return }

        batteryCharacteristic = characteristic
        status = .reading
        if characteristic.properties.contains(.read) {
            peripheral.readValue(for: characteristic)
        }
        if characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) {
            peripheral.setNotifyValue(true, for: characteristic)
        }
        if let currentValue = characteristic.value {
            acceptBatteryValue(currentValue)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard peripheral === pencilPeripheral,
              characteristic.uuid == Self.batteryLevelCharacteristic,
              error == nil,
              let value = characteristic.value else { return }
        acceptBatteryValue(value)
    }
}
