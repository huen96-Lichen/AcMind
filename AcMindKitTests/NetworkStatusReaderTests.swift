import XCTest
@testable import AcMindKit

final class NetworkStatusReaderTests: XCTestCase {
    func testParsePingLatencyExtractsRoundTripTime() {
        let output = """
        64 bytes from 1.1.1.1: icmp_seq=0 ttl=57 time=23.4 ms
        --- 1.1.1.1 ping statistics ---
        """

        XCTAssertEqual(NetworkStatusReader.parsePingLatency(output), Optional(23.4))
    }

    func testReaderIncludesLatencyWhenPingProviderSucceeds() async {
        let reader = NetworkStatusReader(latencyProvider: { 17.8 })

        let partial = await reader.read()

        XCTAssertEqual(partial.networkLatencyMs, Optional(17.8))
    }

    func testReaderReportsLatencyUnavailableWhenPingFails() async {
        let reader = NetworkStatusReader(latencyProvider: { nil })

        let partial = await reader.read()

        XCTAssertTrue(partial.unavailableReasons.contains(where: { $0.id == "network-ping-unavailable" }))
    }

    func testParsePublicIPAddressTrimsWhitespaceAndRejectsEmptyValues() {
        XCTAssertEqual(NetworkStatusReader.parsePublicIPAddress(" 203.0.113.7\n"), "203.0.113.7")
        XCTAssertNil(NetworkStatusReader.parsePublicIPAddress(" \n\t "))
        XCTAssertNil(NetworkStatusReader.parsePublicIPAddress(nil))
    }

    func testReaderIncludesPublicIPAddressWhenLookupSucceeds() async {
        let reader = NetworkStatusReader(
            latencyProvider: { 18.4 },
            publicIPAddressProvider: { "203.0.113.7" }
        )

        let partial = await reader.read()

        XCTAssertEqual(partial.publicIPAddress, "203.0.113.7")
    }

    func testReaderReportsPublicIPAddressUnavailableWhenLookupFails() async {
        let reader = NetworkStatusReader(
            latencyProvider: { 18.4 },
            publicIPAddressProvider: { nil }
        )

        let partial = await reader.read()

        XCTAssertTrue(partial.unavailableReasons.contains(where: { $0.id == "network-public-ip-unavailable" }))
    }

    func testReaderIncludesDNSLookupWhenProviderSucceeds() async {
        let reader = NetworkStatusReader(
            latencyProvider: { 18.4 },
            dnsLookupProvider: { 12.6 },
            publicIPAddressProvider: { "203.0.113.7" }
        )

        let partial = await reader.read()

        XCTAssertEqual(partial.networkDNSLookupMs, Optional(12.6))
    }

    func testReaderReportsDNSLookupUnavailableWhenProviderFails() async {
        let reader = NetworkStatusReader(
            latencyProvider: { 18.4 },
            dnsLookupProvider: { nil },
            publicIPAddressProvider: { "203.0.113.7" }
        )

        let partial = await reader.read()

        XCTAssertTrue(partial.unavailableReasons.contains(where: { $0.id == "network-dns-unavailable" }))
    }

    func testBluetoothParserExtractsConnectedAndPairedDevices() {
        let json = """
        {
          "SPBluetoothDataType": [
            {
              "device_connected": [
                {
                  "AirPods Pro": {
                    "device_address": "AA:BB:CC:DD:EE:FF",
                    "device_batteryLevelMain": "88%",
                    "device_batteryLevelCase": 76
                  }
                }
              ],
              "device_not_connected": [
                {
                  "Magic Keyboard": {
                    "device_address": "11:22:33:44:55:66"
                  }
                }
              ]
            }
          ]
        }
        """

        let devices = BluetoothStatusReader.parseSystemProfilerBluetoothData(json)

        XCTAssertEqual(devices?.count, 2)
        XCTAssertEqual(devices?.first?.name, "AirPods Pro")
        XCTAssertEqual(devices?.first?.address, "aa-bb-cc-dd-ee-ff")
        XCTAssertEqual(devices?.first?.batteryLevel, 88)
        XCTAssertEqual(devices?.first?.batteryDetail, "Main 88% · Case 76%")
    }

    func testBluetoothReaderIncludesDevicesWhenProviderSucceeds() async {
        let reader = BluetoothStatusReader(devicesProvider: {
            [
                SystemBluetoothDeviceSnapshot(
                    id: "aa-bb-cc-dd-ee-ff",
                    name: "AirPods Pro",
                    address: "aa-bb-cc-dd-ee-ff",
                    isConnected: true,
                    isPaired: true,
                    batteryLevel: 88,
                    batteryDetail: "Main 88%",
                    source: "test",
                    isAvailable: true,
                    unavailableReason: nil
                )
            ]
        })

        let partial = await reader.read()

        XCTAssertEqual(partial.bluetoothDevices.count, 1)
        XCTAssertTrue(partial.unavailableReasons.isEmpty)
    }

    func testBluetoothReaderReportsUnavailableWhenProviderFails() async {
        let reader = BluetoothStatusReader(devicesProvider: { nil })

        let partial = await reader.read()

        XCTAssertTrue(partial.unavailableReasons.contains(where: { $0.id == "bluetooth-unavailable" }))
    }
}
