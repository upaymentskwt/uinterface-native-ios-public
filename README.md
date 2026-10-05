# uInterfaceNative

[![Platform: iOS 13+](https://img.shields.io/badge/Platform-iOS%2013%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift: 5.3+](https://img.shields.io/badge/Swift-5.3%2B-orange.svg)](https://swift.org)
[![SPM: Compatible](https://img.shields.io/badge/SPM-Compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**`uInterfaceNative`** is a standalone, lightweight iOS companion SDK designed specifically for native **Apple Pay** payment flows with UPayments. It encapsulates Apple's `PassKit` framework, orchestrates biometric authorization sheets, and extracts encrypted payment tokens into structured, type-safe models ready for backend charge processing.

---

## Features

- 🔒 **Zero Network Dependencies**: Operates completely offline without sending network requests or bundling third-party dependencies.
- 🍏 **Complete PassKit Encapsulation**: Manages `PKPaymentRequest`, `PKPaymentAuthorizationController`, and authorization lifecycle delegates internally.
- ⚡ **Type-Safe Token Deserialization**: Automatically parses Apple Pay's UTF-8 `paymentData` and token metadata into structured models matching UPayments REST API specifications.
- 🧩 **Flexible Integration**: Can be registered into the main `uInterfaceSDK` or consumed directly in custom headless / backend-driven architectures.
- 📦 **Binary Distribution**: Distributed as a pre-compiled, App Store–safe XCFramework via Swift Package Manager.

---

## Requirements

- **iOS**: 13.0 or higher
- **Swift**: 5.3 or higher
- **Xcode**: 14.0 or higher
- **Apple Developer Account**:
  - Registered Merchant Identifier (e.g. `merchant.com.example.app`)
  - Apple Pay Payment Processing Certificate (configured with UPayments CSR)

---

## Installation

### Swift Package Manager (Recommended)

#### Option 1: Via Xcode UI

1. Open your project in Xcode.
2. Navigate to **File** → **Add Package Dependencies...**
3. Enter the repository URL:
   ```text
   https://github.com/upaymentskwt/uinterface-native-ios-public.git
   ```
4. Under **Dependency Rule**, select **Up to Next Major Version** with `1.0.0`.
5. Select **uInterfaceNative** and add it to your target.

#### Option 2: Via `Package.swift`

Add `uinterface-native-ios-public` to your package dependencies:

```swift
// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "YourApp",
    platforms: [
        .iOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/upaymentskwt/uinterface-native-ios-public.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "YourApp",
            dependencies: [
                .product(name: "uInterfaceNative", package: "uinterface-native-ios-public")
            ]
        )
    ]
)
```

---

## Apple Developer Setup

1. In the **Apple Developer Portal**, navigate to **Certificates, Identifiers & Profiles** → **Identifiers** → **Merchant IDs**.
2. Create or select your **Merchant Identifier** (e.g., `merchant.com.yourcompany.app`).
3. Under **Certificates**, generate an **Apple Pay Payment Processing Certificate** using the CSR provided by UPayments.
4. In your Xcode project:
   - Select your target → **Signing & Capabilities** → **+ Capability** → **Apple Pay**.
   - Check the configured Merchant ID.

---

## Quickstart

### 1. Integration with `uInterfaceSDK` (Full Gateway)

If you are using `uInterfaceSDK`, pass your `ApplePayConfiguration` to register native Apple Pay:

```swift
import uInterfaceSDK
import uInterfaceNative

// Configure Host SDK
UPayments.configure(apiKey: "YOUR_API_KEY", environment: .sandbox)

// Register Apple Pay configuration
let applePayConfig = ApplePayConfiguration(
    merchantIdentifier: "merchant.com.yourcompany.app",
    countryCode: "KW",
    supportedNetworks: [.visa, .masterCard, .amex, .mada],
    merchantCapabilities: [.capability3DS, .capabilityDebit, .capabilityCredit],
    merchantName: "Your Store Name"
)
UPayments.shared.configureApplePay(applePayConfig)
```

### 2. Standalone Usage (Direct API Integration)

If you process charges directly via your own backend or UPayments REST API:

```swift
import UIKit
import uInterfaceNative

// 1. Configure Apple Pay
let config = ApplePayConfiguration(
    merchantIdentifier: "merchant.com.yourcompany.app",
    countryCode: "KW",
    supportedNetworks: [.visa, .masterCard, .mada],
    merchantName: "Your Store Name"
)

let processor = ApplePayProcessor(configuration: config)

// 2. Verify device readiness
guard processor.canMakePayments() else {
    print("Apple Pay is not available on this device.")
    return
}

// 3. Initiate payment
processor.startPayment(
    amount: 15.500,
    currency: "KWD",
    summaryItems: [
        ApplePaySummaryItem(label: "Product Order #101", amount: 15.500),
        ApplePaySummaryItem(label: "Your Store Name", amount: 15.500)
    ]
) { result in
    switch result {
    case .success(let payload):
        // Send payload.paymentData and payload.paymentMethod to backend
        print("Apple Pay authorized: \(payload.transactionIdentifier ?? "")")
    case .failure(let error):
        print("Apple Pay error: \(error.localizedDescription)")
    }
}
```

---

## Documentation

For comprehensive guides, API reference, and sequence diagrams, refer to:
- [Companion SDK Integration Guide](docs/companion-sdk.md)
- [Architecture & Sequence Diagrams](docs/architecture-and-sequence-diagrams.md)

---

## License

This SDK is available under the **MIT License**. See [LICENSE](LICENSE) for details.