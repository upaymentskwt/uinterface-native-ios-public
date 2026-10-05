# uInterfaceNative: Standalone Companion SDK Integration Guide

This guide provides complete, external-facing documentation for merchants and developers who wish to integrate **`uInterfaceNative`** directly into their iOS applications.

If you are communicating directly with the **UPayments UInterface REST API** from your own mobile app or backend service, rather than using the full `uInterfaceSDK` UI framework, this standalone guide contains everything you need to implement native Apple Pay.

---

## Table of Contents

1. [Overview](#1-overview)
   - [What is `uInterfaceNative`?](#what-is-uinterfacenative)
   - [When to Integrate Directly](#when-to-integrate-directly)
   - [Relationship to the Main SDK](#relationship-to-the-main-sdk)
2. [Requirements & Prerequisites](#2-requirements--prerequisites)
   - [Platform & Tooling Requirements](#platform--tooling-requirements)
   - [Apple Developer Account Setup](#apple-developer-account-setup)
   - [Xcode Project Capabilities](#xcode-project-capabilities)
3. [Installation](#3-installation)
   - [CocoaPods](#method-a-cocoapods)
   - [Swift Package Manager (SPM)](#method-b-swift-package-manager-spm)
   - [XCFramework (Manual Integration)](#method-c-xcframework-manual-integration)
4. [Configuration & Environments](#4-configuration--environments)
   - [Understanding the Zero-Network Architecture](#understanding-the-zero-network-architecture)
   - [PassKit Device Environment: Sandbox vs Production](#passkit-device-environment-sandbox-vs-production)
   - [Backend API Environment: Sandbox vs Production](#backend-api-environment-sandbox-vs-production)
   - [Switching from Sandbox to Production](#switching-from-sandbox-to-production)
5. [Initialization](#5-initialization)
6. [Step-by-Step Integration Guide](#6-step-by-step-integration-guide)
   - [Step 1: Check Apple Pay Availability](#step-1-check-apple-pay-availability)
   - [Step 2: Add the Apple Pay Button (`PKPaymentButton`)](#step-2-add-the-apple-pay-button-pkpaymentbutton)
   - [Step 3: Define Payment Summary Items](#step-3-define-payment-summary-items)
   - [Step 4: Present Authorization Sheet & Extract Token](#step-4-present-authorization-sheet--extract-token)
   - [Step 5: Submit Extracted Token to UPayments Charge API](#step-5-submit-extracted-token-to-upayments-charge-api)
7. [API Reference](#7-api-reference)
   - [Classes & Structs](#classes--structs)
   - [Protocols](#protocols)
8. [Responses & Error Handling](#8-responses--error-handling)
   - [The `ApplePayError` Enum](#the-applepayerror-enum)
   - [Recommended Handling Patterns](#recommended-handling-patterns)
9. [Production Checklist](#9-production-checklist)
10. [Troubleshooting & FAQs](#10-troubleshooting--faqs)

---

## 1. Overview

### What is `uInterfaceNative`?

`uInterfaceNative` is a modular, lightweight iOS companion SDK designed specifically for native payment methods on Apple devices. It encapsulates Apple's `PassKit` framework, orchestrating payment request generation, biometric sheet presentation, authorization lifecycle events, and token extraction.

Key characteristics:
- **Zero Network Dependencies**: `uInterfaceNative` does not make any direct network calls to UPayments or third-party servers. It has zero external third-party dependencies, keeping your app binary lightweight and secure.
- **PassKit Encapsulation**: Eliminates boilerplate code associated with `PKPaymentRequest`, `PKPaymentAuthorizationController`, and delegate protocols.
- **Type-Safe Token Deserialization**: Deserializes Apple Pay's encrypted UTF-8 `PKPaymentToken.paymentData` and metadata into clean, strongly typed Swift models that map 1:1 to the UPayments REST API.
- **Thread Safety & Lifecycle Management**: Dispatches all completion handlers on the main thread and manages self-retention during the payment sheet presentation to avoid premature deallocation.

### When to Integrate Directly

Integrate `uInterfaceNative` directly when:
1. **Direct API Integration**: Your application or backend already communicates directly with the UPayments UInterface REST API (e.g., `/charge`, `/payment-request`) without requiring the host `uInterfaceSDK`.
2. **Custom Checkout UI**: You maintain your own customized payment selection screens and only need Apple Pay native authorization.
3. **Selective Payment Method Support**: You only offer native Apple Pay on iOS, while routing other payment methods (like KNET or credit cards) through alternate or web flows.
4. **Minimal Binary Footprint**: You want native Apple Pay support without linking WebView coordinators, web form handlers, or larger framework bundles.

### Relationship to the Main SDK

| Aspect | Companion SDK (`uInterfaceNative`) | Main SDK (`uInterfaceSDK`) |
| :--- | :--- | :--- |
| **Primary Scope** | Native Apple Pay PassKit orchestration & token extraction | Full payment gateway (KNET, Credit/Debit Cards, Apple Pay, Invoices, Refunds, Tokenization) |
| **Network Layer** | **None** (Zero network dependencies; returns token payload) | Embedded HTTP client (executes authenticated charge requests) |
| **User Interface** | Apple-native `PKPaymentAuthorizationController` sheet | WKWebView payment coordinators, web callbacks, and form overlays |
| **How Main SDK Uses It** | `uInterfaceSDK` imports `uInterfaceNative` internally to power its `apple-pay` payment handler. | Consumers of `uInterfaceSDK` do not need to call `uInterfaceNative` directly. |

---

## 2. Requirements & Prerequisites

### Platform & Tooling Requirements

- **iOS Deployment Target**: iOS 13.0+ (iOS 15.0+ recommended)
- **Swift Version**: Swift 5.0, 5.3, or 5.5+
- **Xcode Version**: Xcode 14.0 or newer
- **Supported Platforms**: `iphoneos`, `iphonesimulator` (Mac Catalyst is disabled)
- **System Frameworks**: `PassKit`, `UIKit`, `Foundation` (automatically linked)

### Apple Developer Account Setup

To accept Apple Pay in your app, you must configure your Apple Developer account:

1. **Merchant Identifier**:
   - Log in to the [Apple Developer Member Center](https://developer.apple.com/account/).
   - Navigate to **Certificates, Identifiers & Profiles** → **Identifiers** → **Merchant IDs**.
   - Click **+** and create a new Merchant Identifier (e.g., `merchant.com.yourcompany.app`).
2. **Payment Processing Certificate**:
   - Under your Merchant ID settings, locate **Apple Pay Payment Processing Certificate**.
   - Click **Create Certificate**.
   - Obtain a Certificate Signing Request (CSR) from your **UPayments Merchant Dashboard** (or UPayments support team).
   - Upload the CSR to Apple Developer Member Center and download the resulting `.cer` file.
   - Upload the completed certificate back into your UPayments Merchant Dashboard. This enables UPayments servers to decrypt Apple Pay cryptograms generated by your app.

### Xcode Project Capabilities

1. Open your project in Xcode.
2. Select your application target.
3. Go to the **Signing & Capabilities** tab.
4. Click **+ Capability** and select **Apple Pay**.
5. Check the box corresponding to your Merchant Identifier (e.g., `merchant.com.yourcompany.app`).
6. Ensure your App ID provisioning profile includes the Apple Pay entitlement.

---

## 3. Installation

### Method A: CocoaPods

Add `uInterfaceNative` to your `Podfile`:

```ruby
# Podfile
platform :ios, '13.0'
use_frameworks!

target 'YourAppTarget' do
  pod 'uInterfaceNative', '~> 1.0.0'
end
```

If you are consuming directly from the official repository:

```ruby
target 'YourAppTarget' do
  pod 'uInterfaceNative', :git => 'https://github.com/upaymentskwt/uInterface-iOS.git', :tag => '1.0.0'
end
```

Then run:

```bash
pod install
```

### Method B: Swift Package Manager (SPM)

1. In Xcode, select **File** → **Add Packages...**
2. Enter the repository URL:
   ```text
   https://github.com/upaymentskwt/uinterface-native-ios-public.git
   ```
3. Specify the version rule (e.g., Up to Next Major `1.0.0`).
4. Select the **`uInterfaceNative`** product and add it to your application target.

If integrating via `Package.swift`:

```swift
// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "YourApp",
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

### Method C: XCFramework (Manual Integration)

You can build or consume `uInterfaceNative.xcframework` directly:

1. Clone `uInterfaceNative` and run the build script:
   ```bash
   ./build_xcframework.sh
   ```
   The framework is generated at `./framework-builds/uInterfaceNative.xcframework`.
2. Drag `uInterfaceNative.xcframework` into your Xcode project under **Frameworks, Libraries, and Embedded Content**.
3. Set the embed type to **Do Not Embed** (or **Embed & Sign** depending on whether your build distributes dynamic or static frameworks; the default build is static).

---

## 4. Configuration & Environments

### Understanding the Zero-Network Architecture

`uInterfaceNative` has **no direct HTTP network connection**. It runs entirely locally on the iOS device, interacting directly with iOS `PassKit` and the device Secure Element.

Because of this zero-network architecture, the SDK itself does **not** take a `sandbox` vs `production` URL parameter. Instead, Apple Pay environments involve two distinct components:

1. **PassKit Device Environment** (on the iOS device)
2. **UPayments REST API Environment** (on the server/charge endpoint)

```text
┌─────────────────────────────────────────────────────────────┐
│                       iOS Device                            │
│                                                             │
│  [Apple Wallet Cards] ───────► [uInterfaceNative]            │
│  - Sandbox Tester Account         - PassKit Sheet           │
│  - Live Credit/Debit Cards        - Token Extraction        │
└──────────────────────────────────────┬──────────────────────┘
                                       │ ApplePayPaymentTokenPayload
                                       ▼
┌─────────────────────────────────────────────────────────────┐
│               Merchant Backend / App Network                │
│                                                             │
│  Sandbox:    https://sandboxapi.upayments.com/api/v1/charge │
│  Production: https://api.upayments.com/api/v1/charge        │
└─────────────────────────────────────────────────────────────┘
```

### PassKit Device Environment: Sandbox vs Production

| Environment | Apple ID Account | Wallet Cards | Simulator Support |
| :--- | :--- | :--- | :--- |
| **Sandbox** | Apple Sandbox Tester account signed in under **Settings > Wallet & Apple Pay**. | Apple Pay Test Cards provided by Apple/UPayments. | Supported: built-in simulator fallback mock payload for local UI testing. |
| **Production** | Standard Apple ID signed into iCloud. | Real payment cards issued by banks (Visa, MasterCard, Mada, Amex). | Real hardware only (physical iPhone/iPad with Touch ID / Face ID / Passcode). |

> [!TIP]
> **Simulator Testing**: On iOS Simulator, PassKit cannot access the hardware Secure Element. `uInterfaceNative` automatically provides a simulated token payload when running on the simulator so you can test your complete integration and UI flow without a physical device.

### Backend API Environment: Sandbox vs Production

When you transmit the extracted Apple Pay token to the UPayments charge API, select the appropriate endpoint and API key:

| Setting | Sandbox Environment | Production Environment |
| :--- | :--- | :--- |
| **Charge Endpoint** | `https://sandboxapi.upayments.com/api/v1/charge` | `https://api.upayments.com/api/v1/charge` |
| **API Key Header** | `x-api-key: YOUR_SANDBOX_API_KEY` | `x-api-key: YOUR_PRODUCTION_API_KEY` |
| **Authorization** | `Authorization: Bearer YOUR_SANDBOX_API_KEY` | `Authorization: Bearer YOUR_PRODUCTION_API_KEY` |

> [!IMPORTANT]
> UPayments strictly supports standard **Sandbox** and **Production** environments. Never use internal, custom, or unsupported endpoints in production applications.

### Switching from Sandbox to Production

To move your integration to production:
1. Verify that your **Apple Pay Payment Processing Certificate** is activated in your production Apple Developer account and uploaded to your live UPayments dashboard.
2. Ensure your Xcode target capability uses your **Production Merchant ID** (`merchant.com.yourcompany.app`).
3. Point your backend / network client to the **Production Charge Endpoint**: `https://api.upayments.com/api/v1/charge`.
4. Switch your request headers to use your **Production API Key**.
5. Test a small live transaction using a real payment card on a physical iOS device.

---

## 5. Initialization

To initialize `uInterfaceNative`, create an `ApplePayConfiguration` and instantiate `ApplePayProcessor`:

```swift
import UIKit
import PassKit
import uInterfaceNative

class CheckoutViewController: UIViewController {
    
    private var applePayProcessor: ApplePayProcessor?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupApplePay()
    }
    
    private func setupApplePay() {
        // 1. Create configuration
        let configuration = ApplePayConfiguration(
            merchantIdentifier: "merchant.com.yourcompany.app",
            countryCode: "KW", // 2-letter ISO 3166-1 alpha-2 code
            supportedNetworks: [.visa, .masterCard, .mada, .amex],
            merchantCapabilities: [.capability3DS, .capabilityDebit, .capabilityCredit],
            merchantName: "My Store Name",
            requiresActiveCards: false // Set to false to allow users without cards to add one
        )
        
        // 2. Instantiate processor
        self.applePayProcessor = ApplePayProcessor(configuration: configuration)
    }
}
```

---

## 6. Step-by-Step Integration Guide

### Step 1: Check Apple Pay Availability

Before displaying the Apple Pay button, always verify that the user's device supports Apple Pay:

```swift
guard let processor = applePayProcessor, processor.canMakePayments() else {
    // Hide Apple Pay button or offer alternative payment methods
    print("Apple Pay is not supported on this device.")
    return
}
```

- `processor.canMakePayments()`: Returns `true` if the device hardware and parental controls permit Apple Pay.
- `processor.canMakePaymentsWithActiveCards()`: Returns `true` only if the user already has at least one active card matching your `supportedNetworks` and `merchantCapabilities` enrolled in Apple Wallet. 
  *(Recommended: Keep `requiresActiveCards: false` so PassKit allows the user to add a card on the fly).*

### Step 2: Add the Apple Pay Button (`PKPaymentButton`)

Apple requires the use of `PKPaymentButton` for brand consistency. Add it to your view hierarchy:

```swift
private func setupApplePayButton() {
    guard let processor = applePayProcessor, processor.canMakePayments() else { return }
    
    let payButton = PKPaymentButton(paymentButtonType: .buy, paymentButtonStyle: .black)
    payButton.translatesAutoresizingMaskIntoConstraints = false
    payButton.addTarget(self, action: #selector(didTapApplePayButton), for: .touchUpInside)
    
    view.addSubview(payButton)
    
    NSLayoutConstraint.activate([
        payButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        payButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
        payButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
        payButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        payButton.heightAnchor.constraint(equalToConstant: 48)
    ])
}
```

### Step 3: Define Payment Summary Items

Create `ApplePaySummaryItem` instances representing each line item and the total:

```swift
let summaryItems: [ApplePaySummaryItem] = [
    ApplePaySummaryItem(label: "Wireless Headphones", amount: 15.00),
    ApplePaySummaryItem(label: "Express Shipping", amount: 2.50),
    ApplePaySummaryItem(label: "My Store Name", amount: 17.50) // Final total item
]
```

> [!NOTE]
> If your `summaryItems` list does not end with an item matching the total transaction amount, `ApplePayProcessor` will automatically append a final summary item using `configuration.merchantName ?? "Total"` and the specified amount.

### Step 4: Present Authorization Sheet & Extract Token

When the user taps the Apple Pay button, invoke `processor.startPayment(...)`:

```swift
@objc private func didTapApplePayButton() {
    guard let processor = applePayProcessor else { return }
    
    let totalAmount: Double = 17.50
    let currencyCode: String = "KWD"
    
    let summaryItems: [ApplePaySummaryItem] = [
        ApplePaySummaryItem(label: "Wireless Headphones", amount: 15.00),
        ApplePaySummaryItem(label: "Express Shipping", amount: 2.50),
        ApplePaySummaryItem(label: "My Store Name", amount: 17.50)
    ]
    
    processor.startPayment(
        amount: totalAmount,
        currency: currencyCode,
        summaryItems: summaryItems
    ) { [weak self] result in
        guard let self = self else { return }
        
        switch result {
        case .success(let tokenPayload):
            print("Apple Pay authorization succeeded!")
            print("Transaction ID: \(tokenPayload.transactionIdentifier ?? "N/A")")
            print("Card Network: \(tokenPayload.paymentMethod.network ?? "Unknown")")
            print("Card Type: \(tokenPayload.paymentMethod.type ?? "Unknown")")
            
            // Forward the tokenPayload to your backend / UPayments charge API
            self.submitPaymentToBackend(tokenPayload: tokenPayload, amount: totalAmount, currency: currencyCode)
            
        case .failure(let error):
            self.handleApplePayError(error)
        }
    }
}
```

### Step 5: Submit Extracted Token to UPayments Charge API

After obtaining `ApplePayPaymentTokenPayload`, submit the transaction to the UPayments charge API.

#### Expected Request Payload Structure

The `ApplePayPaymentTokenPayload` matches the `paymentGateway.token` object expected by the UPayments charge API:

```json
{
  "order": {
    "id": "ORD_987654",
    "amount": 17.50,
    "currency": "KWD"
  },
  "paymentGateway": {
    "src": "apple-pay",
    "token": {
      "transactionIdentifier": "3369...7890",
      "paymentData": {
        "data": "t3xP...b7A==",
        "signature": "MIAG...AAAA==",
        "version": "EC_v1",
        "header": {
          "publicKeyHash": "rP8Y...4E0Ow=",
          "ephemeralPublicKey": "MFkw...95A==",
          "transactionId": "ab17...5cb8"
        }
      },
      "paymentMethod": {
        "type": "debit",
        "network": "Visa",
        "displayName": "Visa 1030"
      }
    }
  },
  "language": "en",
  "reference": {
    "id": "REF_12345"
  },
  "returnUrl": "https://yourdomain.com/payment/success",
  "cancelUrl": "https://yourdomain.com/payment/cancel",
  "notificationUrl": "https://yourdomain.com/payment/webhook"
}
```

#### Swift Networking Implementation Example

Below is a complete, copy-pasteable example of submitting the token payload from an iOS app or backend client:

```swift
import Foundation
import uInterfaceNative

struct UPaymentsChargeService {
    
    enum Environment {
        case sandbox
        case production
        
        var chargeURL: URL {
            switch self {
            case .sandbox:
                return URL(string: "https://sandboxapi.upayments.com/api/v1/charge")!
            case .production:
                return URL(string: "https://api.upayments.com/api/v1/charge")!
            }
        }
    }
    
    private let apiKey: String
    private let environment: Environment
    
    init(apiKey: String, environment: Environment) {
        self.apiKey = apiKey
        self.environment = environment
    }
    
    func chargeApplePay(
        orderId: String,
        amount: Double,
        currency: String,
        tokenPayload: ApplePayPaymentTokenPayload,
        returnUrl: String,
        cancelUrl: String,
        notificationUrl: String,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        var request = URLRequest(url: environment.chargeURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        // Encode tokenPayload using standard JSONEncoder
        let encoder = JSONEncoder()
        guard let tokenData = try? encoder.encode(tokenPayload),
              let tokenJSONObject = try? JSONSerialization.jsonObject(with: tokenData) as? [String: Any] else {
            completion(.failure(NSError(domain: "UPayments", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode token payload"])))
            return
        }
        
        let body: [String: Any] = [
          "order": [
            "id": orderId,
            "amount": amount,
            "currency": currency
          ],
          "paymentGateway": [
            "src": "apple-pay",
            "token": tokenJSONObject
          ],
          "language": "en",
          "reference": [
            "id": "REF_\(orderId)"
          ],
          "returnUrl": returnUrl,
          "cancelUrl": cancelUrl,
          "notificationUrl": notificationUrl
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            
            guard let data = data,
                  let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                let parseError = NSError(domain: "UPayments", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
                DispatchQueue.main.async { completion(.failure(parseError)) }
                return
            }
            
            DispatchQueue.main.async {
                completion(.success(json))
            }
        }.resume()
    }
}
```

---

## 7. API Reference

### Classes & Structs

#### `ApplePayConfiguration`
Configuration settings for Apple Pay sessions.

```swift
public struct ApplePayConfiguration: Equatable {
    public let merchantIdentifier: String
    public let countryCode: String
    public let supportedNetworks: [PKPaymentNetwork]
    public let merchantCapabilities: PKMerchantCapability
    public let merchantName: String?
    public let requiresActiveCards: Bool

    public init(
        merchantIdentifier: String,
        countryCode: String = "KW",
        supportedNetworks: [PKPaymentNetwork] = [.visa, .masterCard, .mada, .amex],
        merchantCapabilities: PKMerchantCapability = [.capability3DS, .capabilityDebit, .capabilityCredit],
        merchantName: String? = nil,
        requiresActiveCards: Bool = false
    )
}
```

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `merchantIdentifier` | `String` | *(Required)* | Apple Merchant ID registered in Apple Developer Portal (e.g. `merchant.com.example`). |
| `countryCode` | `String` | `"KW"` | Two-letter ISO 3166-1 alpha-2 country code (`KW`, `SA`, `AE`, `US`, etc.). |
| `supportedNetworks` | `[PKPaymentNetwork]` | `[.visa, .masterCard, .mada, .amex]` | Payment card networks accepted by your store. |
| `merchantCapabilities` | `PKMerchantCapability` | `[.capability3DS, .capabilityDebit, .capabilityCredit]` | Merchant capabilities supported. 3DS is required. |
| `merchantName` | `String?` | `nil` | Display name of your store shown on the final total summary line. |
| `requiresActiveCards` | `Bool` | `false` | If `true`, checks for enrolled cards before presenting. When `false`, users can add a card during checkout. |

---

#### `ApplePaySummaryItem`
Represents a line item displayed in the Apple Pay authorization sheet.

```swift
public struct ApplePaySummaryItem: Equatable {
    public let label: String
    public let amount: NSDecimalNumber
    public let type: PKPaymentSummaryItemType

    public init(label: String, amount: Double, type: PKPaymentSummaryItemType = .final)
    public init(label: String, decimalAmount: NSDecimalNumber, type: PKPaymentSummaryItemType = .final)
    public func toPKPaymentSummaryItem() -> PKPaymentSummaryItem
}
```

---

#### `ApplePayProcessor`
The primary coordinator managing PassKit lifecycle, presentation, and token extraction.

```swift
public class ApplePayProcessor: NSObject, ApplePayProcessorProtocol {
    public let configuration: ApplePayConfiguration

    public init(
        configuration: ApplePayConfiguration,
        authorizerFactory: PKPaymentAuthorizerFactory = DefaultPKPaymentAuthorizerFactory()
    )

    public func canMakePayments() -> Bool
    public func canMakePaymentsWithActiveCards() -> Bool

    public func makePaymentRequest(
        amount: Double,
        currency: String,
        summaryItems: [ApplePaySummaryItem]?
    ) throws -> PKPaymentRequest

    public func startPayment(
        amount: Double,
        currency: String,
        summaryItems: [ApplePaySummaryItem]?,
        completion: @escaping (Result<ApplePayPaymentTokenPayload, ApplePayError>) -> Void
    )

    public func extractPaymentTokenPayload(from payment: PKPayment) throws -> ApplePayPaymentTokenPayload
}
```

---

#### `ApplePayPaymentTokenPayload`
The root token structure extracted upon successful authorization.

```swift
public struct ApplePayPaymentTokenPayload: Codable, Equatable {
    public let transactionIdentifier: String?
    public let paymentData: ApplePayPaymentData
    public let paymentMethod: ApplePayPaymentMethodInfo
}
```

#### `ApplePayPaymentData`
Encrypted Apple Pay token details.

```swift
public struct ApplePayPaymentData: Codable, Equatable {
    public let data: String
    public let signature: String
    public let version: String
    public let header: ApplePayPaymentHeader
}
```

#### `ApplePayPaymentHeader`
Decryption header for payment processing gateways.

```swift
public struct ApplePayPaymentHeader: Codable, Equatable {
    public let publicKeyHash: String?
    public let ephemeralPublicKey: String?
    public let transactionId: String?
    public let wrappedKey: String?
}
```

#### `ApplePayPaymentMethodInfo`
Metadata describing the customer's selected card.

```swift
public struct ApplePayPaymentMethodInfo: Codable, Equatable {
    public let type: String?        // "debit", "credit", "prepaid", "store", or "unknown"
    public let network: String?     // e.g. "Visa", "MasterCard", "Amex"
    public let displayName: String? // e.g. "Visa 1030"
}
```

---

### Protocols

#### `ApplePayProcessorProtocol`
Defines the public interface for the processor engine.

```swift
public protocol ApplePayProcessorProtocol: AnyObject {
    var configuration: ApplePayConfiguration { get }
    func canMakePayments() -> Bool
    func canMakePaymentsWithActiveCards() -> Bool
    func makePaymentRequest(amount: Double, currency: String, summaryItems: [ApplePaySummaryItem]?) throws -> PKPaymentRequest
    func startPayment(
        amount: Double,
        currency: String,
        summaryItems: [ApplePaySummaryItem]?,
        completion: @escaping (Result<ApplePayPaymentTokenPayload, ApplePayError>) -> Void
    )
}
```

---

## 8. Responses & Error Handling

### The `ApplePayError` Enum

All errors returned by `startPayment` conform to `ApplePayError`:

```swift
@frozen public enum ApplePayError: Error, LocalizedError, CustomStringConvertible, Equatable {
    case deviceNotSupported
    case noSupportedCards
    case missingMerchantIdentifier
    case invalidAmount(Double)
    case invalidCurrency(String)
    case invalidCountryCode(String)
    case userCancelled
    case authorizationFailed(String?)
    case tokenSerializationFailed(String)
    case passKitError(String)
    case unknown(String)
}
```

| Error Case | Description | Common Cause | Action / Resolution |
| :--- | :--- | :--- | :--- |
| `.userCancelled` | The user dismissed or cancelled the Apple Pay sheet. | Normal user action (tapped Cancel or dismissed sheet). | Silently dismiss; do not display error alerts to the user. |
| `.deviceNotSupported` | Apple Pay is not supported on this device. | Device lacks Secure Element or has parental restrictions enabled. | Hide Apple Pay button or display alternative payment options. |
| `.noSupportedCards` | No cards matching configured networks are enrolled in Wallet. | `requiresActiveCards: true` was set and user's Wallet is empty. | Keep `requiresActiveCards: false` so PassKit prompts to add a card. |
| `.missingMerchantIdentifier` | Merchant ID is empty or whitespace. | `ApplePayConfiguration` has empty `merchantIdentifier`. | Verify your Merchant ID (e.g. `merchant.com.yourcompany.app`). |
| `.invalidAmount(Double)` | Amount is non-positive (`<= 0`). | Passing `0.0` or negative values. | Ensure amount is greater than zero before calling `startPayment`. |
| `.invalidCurrency(String)` | Currency code is invalid. | Passing empty string or currency code not 3 characters. | Provide valid 3-letter ISO 4217 code (e.g. `"KWD"`, `"SAR"`, `"AED"`). |
| `.invalidCountryCode(String)`| Country code is invalid. | Country code is empty or malformed. | Provide valid 2-letter ISO 3166-1 alpha-2 code (`"KW"`, `"SA"`, `"AE"`). |
| `.authorizationFailed(String?)`| Biometric or passcode verification failed. | User authentication rejected on device. | Allow the user to retry payment. |
| `.tokenSerializationFailed(String)`| Token extraction or JSON parsing failed. | Corrupt or unexpected PassKit token structure. | Verify Apple Pay Payment Processing Certificate configuration. |
| `.passKitError(String)` | Internal PassKit presentation error. | Presentation view controller conflict or invalid request parameters. | Inspect the error message and check view hierarchy. |
| `.unknown(String)` | An unexpected system error occurred. | Internal system exception. | Log error details and prompt user to retry. |

### Recommended Handling Patterns

```swift
private func handleApplePayError(_ error: ApplePayError) {
    switch error {
    case .userCancelled:
        // Do not alert the user; simply resume checkout view state
        print("User cancelled Apple Pay.")
        
    case .deviceNotSupported, .noSupportedCards:
        showAlert(title: "Apple Pay Unavailable", message: "Please select an alternative payment method.")
        
    case .invalidAmount, .invalidCurrency, .invalidCountryCode, .missingMerchantIdentifier:
        // Developer / configuration errors
        print("Integration Error: \(error.localizedDescription)")
        showAlert(title: "Payment Error", message: "An error occurred while preparing your payment. Please try again.")
        
    case .authorizationFailed(let reason):
        showAlert(title: "Authorization Failed", message: reason ?? "Could not authorize payment. Please try again.")
        
    case .tokenSerializationFailed, .passKitError, .unknown:
        showAlert(title: "Payment Error", message: error.localizedDescription)
    }
}
```

---

## 9. Production Checklist

Complete this checklist prior to launching your app to the App Store:

- [ ] **Apple Developer Merchant ID**: Created and active under **Identifiers** in the Apple Developer Member Center.
- [ ] **Payment Processing Certificate**: Generated using the CSR provided by UPayments, signed by Apple, and uploaded into the UPayments dashboard.
- [ ] **Xcode Target Capabilities**: **Apple Pay** capability enabled with the correct Merchant Identifier checked.
- [ ] **Deployment Target & Build**: Minimum iOS version set to 13.0 or higher.
- [ ] **Environment Endpoints**: Switched from `https://sandboxapi.upayments.com/api/v1/charge` to `https://api.upayments.com/api/v1/charge`.
- [ ] **API Credentials**: Switched from Sandbox API Key to Production API Key in authorization headers.
- [ ] **Live Physical Device Test**: Successfully processed a transaction using a live credit or debit card on a physical iPhone.
- [ ] **Webhook / Callback Verification**: Confirmed that your server receives payment webhooks sent to your `notificationUrl`.
- [ ] **Human Interface Guidelines (HIG)**: Used official `PKPaymentButton`, ensured accurate line-item pricing, and verified that the total matches your cart.

---

## 10. Troubleshooting & FAQs

### Q1: Why does `canMakePayments()` return `false`?
- **Simulator limitations**: On older Xcode simulators or configurations without Wallet support, Apple Pay may report unavailable. On physical devices, ensure that device restrictions (Screen Time) have not disabled Apple Pay.
- **Hardware**: The device must support Touch ID, Face ID, or an active device passcode.

### Q2: Why does PassKit log `Invalid in-app payment request`?
- Apple requires a valid 2-letter uppercase ISO 3166-1 alpha-2 country code (`KW`, `SA`, `AE`, `US`, etc.).
- Ensure your `merchantIdentifier` matches the identifier enabled in your Xcode target's entitlements.
- Ensure the transaction `amount` is strictly greater than zero and `currency` is a 3-letter ISO code.

### Q3: Why does the Apple Pay sheet fail or show "Payment Not Completed"?
- This commonly occurs if your **Apple Pay Payment Processing Certificate** is missing, expired, or was created with a CSR from a different gateway account.
- Log in to your UPayments Merchant Portal to verify certificate status.

### Q4: Does `uInterfaceNative` handle 3D Secure for Apple Pay?
- Apple Pay cards with device-specific cryptographic tokens (DPAN) utilize tokenized cryptograms that inherently satisfy Strong Customer Authentication (SCA) requirements.
- By configuring `merchantCapabilities: [.capability3DS, .capabilityDebit, .capabilityCredit]`, PassKit ensures that cards requiring 3DS authorization handle it seamlessly within the Apple Pay sheet.

### Q5: How do I handle simulator testing when I don't have test cards?
- `uInterfaceNative` contains built-in simulation support for iOS Simulator targets (`#if targetEnvironment(simulator)`).
- When running on a simulator, `extractPaymentTokenPayload` automatically supplies mock payment data with a synthetic `transactionId`, `header`, and `version` (`"EC_v1"`), allowing you to test your UI and network submission without physical hardware.

---

## Need Assistance?

For inquiries regarding merchant onboarding, Apple Pay CSR generation, or API credentials, contact UPayments support:
- **Website**: [https://upayments.com](https://upayments.com)
- **Technical Support**: `license@upayments.com`
