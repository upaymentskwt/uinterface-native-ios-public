# UPayments iOS SDKs: Architecture & Sequence Diagrams

This document provides architectural blueprints and comprehensive sequence diagrams for both the **Companion SDK (`uInterfaceNative`)** and the **Main SDK (`uInterfaceSDK`)**, as documented in:
- [`docs/companion-sdk.md`](file:///Users/siyahulhaq/Work/UPayments/SDKs/uInterfaceNative/docs/companion-sdk.md)
- [`../iOS-SDK/docs/main-sdk.md`](file:///Users/siyahulhaq/Work/UPayments/SDKs/iOS-SDK/docs/main-sdk.md)

---

## Table of Contents

1. [Architectural Overview & Integration Paths](#1-architectural-overview--integration-paths)
2. [Integration Path Decision Tree](#2-integration-path-decision-tree)
3. [Companion SDK (`uInterfaceNative`) Architecture](#3-companion-sdk-uinterfacenative-architecture)
   - [3.1 Zero-Network PassKit Orchestration Diagram](#31-zero-network-passkit-orchestration-diagram)
   - [3.2 Design Characteristics](#32-design-characteristics)
4. [Companion SDK Sequence Diagram](#4-companion-sdk-sequence-diagram)
   - [4.1 Sequence Diagram: Standalone Direct Apple Pay & Charge API Flow](#41-sequence-diagram-standalone-direct-apple-pay--charge-api-flow)
5. [Main SDK (`uInterfaceSDK`) Architecture](#5-main-sdk-uinterfacesdk-architecture)
   - [5.1 Clean Architecture Layer Diagram](#51-clean-architecture-layer-diagram)
   - [5.2 Architectural Invariants & Boundary Rules](#52-architectural-invariants--boundary-rules)
6. [Main SDK Sequence Diagrams](#6-main-sdk-sequence-diagrams)
   - [6.1 Sequence Diagram: Web / Hosted Checkout (KNET & Credit Card)](#61-sequence-diagram-web--hosted-checkout-knet--credit-card)
   - [6.2 Sequence Diagram: Native Apple Pay via Companion SDK Binding](#62-sequence-diagram-native-apple-pay-via-companion-sdk-binding)
   - [6.3 Sequence Diagram: Card Tokenization & Auto-Deduct Billing](#63-sequence-diagram-card-tokenization--auto-deduct-billing)
7. [Comparative Summary: Main SDK vs Companion SDK](#7-comparative-summary-main-sdk-vs-companion-sdk)

---

## 1. Architectural Overview & Integration Paths

Merchants integrating UPayments on iOS can adopt one of two architectural patterns depending on whether they require a complete turnkey checkout experience or a lightweight, native-only Apple Pay component:

```mermaid
graph TD
    classDef mainSDK fill:#e8f4fd,stroke:#1976d2,stroke-width:2px,color:#0d47a1;
    classDef companion fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px,color:#4a148c;
    classDef merchant fill:#e8f8f5,stroke:#00897b,stroke-width:2px,color:#004d40;
    classDef backend fill:#fff3e0,stroke:#f57c00,stroke-width:2px,color:#e65100;

    subgraph MerchantApp["Merchant iOS Application"]
        AppUI["Merchant App UI / Checkout Screen"]:::merchant
    end

    subgraph MainSDKPath["Path A: Full SDK Integration (uInterfaceSDK)"]
        UPaymentsFacade["UPayments Facade & Core Router"]:::mainSDK
        WebCoordinators["Presentation Layer (WKWebView Modal Sheet)"]:::mainSDK
        DomainData["Domain & Data Layers (HMAC Auth, UseCases, Repos)"]:::mainSDK
    end

    subgraph CompanionSDK["Path B: Standalone Companion SDK (uInterfaceNative)"]
        NativeProcessor["ApplePayProcessor (PassKit Encapsulation)"]:::companion
    end

    subgraph AppleEcosystem["Apple Ecosystem"]
        PassKit["PassKit / Apple Pay Biometric Sheet"]
    end

    subgraph UPaymentsCloud["UPayments Backend Platform"]
        API["UPayments REST API (/charge, /payment-request, /credentials)"]:::backend
    end

    %% Path A Connections
    AppUI -->|"Configure & Process Payment"| UPaymentsFacade
    UPaymentsFacade -->|"Web Checkout (KNET, CC)"| WebCoordinators
    UPaymentsFacade -->|"API Operations"| DomainData
    UPaymentsFacade -.->|"Internal Binding (apple-pay)"| NativeProcessor
    DomainData -->|"Authenticated HTTPS Requests"| API

    %% Path B Connections
    AppUI -->|"Direct Apple Pay Request"| NativeProcessor
    NativeProcessor <-->|"Present Sheet & Authorize"| PassKit
    AppUI -->|"Submit Extracted Token (/charge)"| API
```

---

## 2. Integration Path Decision Tree

Use the following flowchart to determine whether to integrate the **Main SDK (`uInterfaceSDK`)** or the standalone **Companion SDK (`uInterfaceNative`)**:

```mermaid
flowchart TD
    Start(["Merchant Integration Assessment"]) --> Q1{"Do you need KNET, Credit/Debit cards, saved cards, or invoice generation?"}
    
    Q1 -- "Yes" --> ChooseMain["Integrate Main SDK (uInterfaceSDK)"]
    Q1 -- "No, Apple Pay only" --> Q2{"Does your app already connect directly to UPayments REST API (/charge)?"}
    
    Q2 -- "Yes" --> ChooseCompanion["Integrate Standalone Companion SDK (uInterfaceNative)"]
    Q2 -- "No (Prefer all-in-one SDK handling auth, API calls, and sheets)" --> ChooseMain

    ChooseMain --> BenefitMain["Benefits:<br/>• Turnkey WKWebView 3DS handling<br/>• Automated HMAC auth signing<br/>• Built-in Apple Pay delegation<br/>• Pre-flight validation"]
    ChooseCompanion --> BenefitCompanion["Benefits:<br/>• Zero network dependencies<br/>• Minimal binary footprint<br/>• Type-safe token deserialization<br/>• Full UI & network control"]
```

---

## 3. Companion SDK (`uInterfaceNative`) Architecture

The standalone **`uInterfaceNative`** framework is an ultra-lightweight, zero-network companion designed solely for native Apple Pay orchestration and token parsing.

### 3.1 Zero-Network PassKit Orchestration Diagram

```mermaid
graph TB
    classDef compCore fill:#f3e5f5,stroke:#6a1b9a,stroke-width:2px,color:#38006b;
    classDef compModels fill:#ede7f6,stroke:#4527a0,stroke-width:2px,color:#1a237e;
    classDef compApple fill:#e1f5fe,stroke:#0277bd,stroke-width:2px,color:#01579b;
    classDef compExt fill:#fff3e0,stroke:#e65100,stroke-width:2px,color:#bf360c;

    subgraph CompanionSDK["uInterfaceNative Framework (Zero-Network Domain)"]
        ApplePayProc["ApplePayProcessor (Singleton / Instance)<br/>• Availability checks: isApplePayAvailable()<br/>• Request orchestration: requestPayment()<br/>• Self-retention lifecycle management<br/>• Main thread dispatching"]:::compCore
        
        PassKitDelegate["PKPaymentAuthorizationControllerDelegate<br/>• paymentAuthorizationController(_:didAuthorizePayment:)<br/>• paymentAuthorizationControllerDidFinish(_)"]:::compCore

        subgraph PublicModels["Public Strongly-Typed Models"]
            RequestModel["ApplePayRequest<br/>• merchantIdentifier<br/>• countryCode, currencyCode<br/>• summaryItems: [ApplePaySummaryItem]<br/>• supportedNetworks<br/>• merchantCapabilities"]:::compModels
            
            TokenPayload["ApplePayPaymentTokenPayload<br/>• paymentData (ApplePayPaymentData)<br/>• paymentMethod (ApplePayPaymentMethod)<br/>• transactionIdentifier"]:::compModels
            
            ErrorEnum["ApplePayError<br/>• applePayNotSupported<br/>• noActiveCard<br/>• invalidRequest<br/>• presentationFailed<br/>• userCancelled<br/>• tokenExtractionFailed"]:::compModels
        end

        subgraph Deserializer["Token Deserialization Engine"]
            JSONParser["PaymentData UTF-8 JSON Parser<br/>(Extracts cryptogram, signature, header, version)"]:::compCore
        end
    end

    subgraph AppleFrameworks["System Frameworks (PassKit & UIKit)"]
        PKReq["PKPaymentRequest"]:::compApple
        PKAuthCtrl["PKPaymentAuthorizationController"]:::compApple
        PKToken["PKPaymentToken (Encrypted Payload)"]:::compApple
    end

    subgraph IntegrationPoints["Merchant Consumption Context"]
        DirectMerchant["Merchant App (Standalone Integration)"]:::compExt
        MainSDKBinding["uInterfaceSDK (Bound via ApplePayPaymentHandler)"]:::compExt
        DirectAPI["Merchant App/Backend -> POST /charge"]:::compExt
    end

    %% Interactions
    DirectMerchant -->|"Check & Request"| ApplePayProc
    MainSDKBinding -->|"Request"| ApplePayProc
    ApplePayProc --> RequestModel
    ApplePayProc --> PKReq
    ApplePayProc --> PKAuthCtrl
    ApplePayProc -.-> PassKitDelegate
    PKAuthCtrl <--> PassKitDelegate
    PKAuthCtrl --> PKToken
    PassKitDelegate --> JSONParser
    JSONParser --> TokenPayload
    ApplePayProc -->|"Completion Result"| TokenPayload
    ApplePayProc -->|"Completion Error"| ErrorEnum

    TokenPayload -->|"Returned to Merchant"| DirectMerchant
    DirectMerchant -->|"Submits Payload"| DirectAPI
```

### 3.2 Design Characteristics

- **Zero Network Invariant**: `uInterfaceNative` never initiates HTTP requests. It contains no networking libraries, ensuring merchants full sovereignty over their networking stack.
- **PassKit Encapsulation**: Masks complex `PKPaymentAuthorizationController` boilerplate, delegate methods, and retained lifecycle state.
- **Deterministic Threading**: Completion handlers are guaranteed to execute on `DispatchQueue.main`, protecting calling applications from threading hazards.
- **Deep Token Parsing**: Converts raw UTF-8 `PKPaymentToken.paymentData` bytes into strongly typed Swift structs (`ApplePayPaymentData`, `ApplePayPaymentMethod`), matching UPayments' backend `/charge` specification directly.

---

## 4. Companion SDK Sequence Diagram

### 4.1 Sequence Diagram: Standalone Direct Apple Pay & Charge API Flow

```mermaid
sequenceDiagram
    autonumber
    actor Customer
    participant App as Merchant iOS App
    participant Proc as ApplePayProcessor
    participant PassKit as PKPaymentAuthorizationController
    participant Backend as Merchant Server / UPayments API

    App->>Proc: isApplePayAvailable(networks: [.visa, .masterCard, .mada])
    Proc-->>App: true
    
    App->>Customer: Display PKPaymentButton(type: .buy, style: .black)
    Customer->>App: Taps Apple Pay Button

    Note over App: Builds ApplePayRequest with summary items,<br/>currency, and Apple Merchant Identifier
    App->>Proc: requestPayment(request: applePayRequest) { result in ... }
    
    Proc->>PassKit: Build PKPaymentRequest & present()
    PassKit->>Customer: Display Native Payment Sheet (Face ID / Touch ID)

    alt Customer Authorizes Payment
        Customer->>PassKit: Biometric Verification Succeeded
        PassKit->>Proc: didAuthorizePayment(payment, handler)
        
        Note over Proc: Extracts payment.token<br/>Deserializes paymentData JSON<br/>Constructs ApplePayPaymentTokenPayload
        
        Proc->>PassKit: handler(PKPaymentAuthorizationResult(status: .success))
        PassKit-->>Customer: Display Checkmark & Dismiss Sheet
        PassKit->>Proc: paymentAuthorizationControllerDidFinish()
        
        Proc-->>App: completion(.success(ApplePayPaymentTokenPayload))
        
        Note over App: Forward extracted cryptogram payload<br/>to UPayments Charge REST endpoint
        App->>Backend: POST /charge (with ApplePayPaymentTokenPayload)
        Backend-->>App: 200 OK (Payment Approved, receiptId, trackId)
        App->>Customer: Present Order Confirmation
    else Customer Dismisses / Cancels Sheet
        Customer->>PassKit: Taps "Cancel" / Pulls down sheet
        PassKit->>Proc: paymentAuthorizationControllerDidFinish()
        Proc-->>App: completion(.failure(.userCancelled))
        App->>App: Dismiss cleanly without showing error popups
    end
```

---

## 5. Main SDK (`uInterfaceSDK`) Architecture

The Main SDK follows **Clean Architecture** principles. The codebase is organized into four distinct rings of responsibility where dependencies flow strictly inward.

### 5.1 Clean Architecture Layer Diagram

```mermaid
graph TB
    classDef pres fill:#e3f2fd,stroke:#1565c0,stroke-width:2px,color:#0d47a1;
    classDef core fill:#ede7f6,stroke:#512da8,stroke-width:2px,color:#311b92;
    classDef dom fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px,color:#1b5e20;
    classDef data fill:#fffde7,stroke:#fbc02d,stroke-width:2px,color:#f57f17;
    classDef ext fill:#fbe9e7,stroke:#d84315,stroke-width:2px,color:#bf360c;

    subgraph PresentationLayer["Presentation Layer (Sources/Presentation)"]
        WebFlowCoord["PaymentWebFlowCoordinatorProtocol<br/>PaymentWebFlowCoordinator"]:::pres
        CardFlowCoord["CardWebFlowCoordinatorProtocol<br/>CardWebFlowCoordinator"]:::pres
        WebVC["PaymentWebViewController (WKWebView)<br/>• Viewport Zoom Disable Script<br/>• URL Redirection Interceptor<br/>• Query Param Transaction Parser"]:::pres
        CardVC["AddCardController"]:::pres
    end

    subgraph CoreLayer["Core Layer (Sources/Core)"]
        UPayments["UPayments (Unified Public Facade)"]:::core
        SDKConfig["SDKConfiguration (Thread-Safe Config)"]:::core
        PaymentRouter["PaymentRouter<br/>(Pluggable PaymentMethodHandler Registry)"]:::core
        ApplePayHandler["ApplePayPaymentHandler<br/>(Conforms to PaymentMethodHandler)"]:::core
        LegacyAdapter["PaymentGatewayImplementation<br/>PaymentAPIManager (Backward Compatibility)"]:::core
    end

    subgraph DomainLayer["Domain Layer (Sources/Domain) - Zero UI/Network Imports"]
        subgraph UseCases["Single-Responsibility Use Cases"]
            InitUC["InitializeSDKUseCase"]:::dom
            ProcessUC["ProcessPaymentUseCase"]:::dom
            StatusUC["FetchPaymentStatusUseCase"]:::dom
            ButtonUC["CheckPaymentButtonStatusUseCase"]:::dom
            AutoDeductUC["AutoDeductPaymentUseCase"]:::dom
            CardUCs["CreateCustomerTokenUseCase<br/>FetchCustomerCardsUseCase<br/>AddCustomerCardUseCase"]:::dom
            RefundUCs["CreateRefundUseCase<br/>CreateMultiVendorRefundUseCase<br/>DeleteRefundUseCase"]:::dom
            InvoiceUC["CreateInvoiceUseCase"]:::dom
        end

        subgraph DomainProtocols["Repository Interfaces & Pre-Flight Validation"]
            RepoProtocols["PaymentRepositoryProtocol<br/>CredentialsRepositoryProtocol<br/>CardRepositoryProtocol<br/>RefundRepositoryProtocol<br/>InvoiceRepositoryProtocol"]:::dom
            ValidationEngine["Pre-Flight Request Validation<br/>(Fails fast on missing required fields)"]:::dom
        end

        subgraph Entities["Domain Entities & Result Models"]
            EntitiesModels["PaymentRequestModel, PaymentResult<br/>TransactionDetails, CustomerCardsResult<br/>NetworkError"]:::dom
        end
    end

    subgraph DataLayer["Data Layer (Sources/Data & Sources/NetworkManager)"]
        BaseRepo["BaseAuthenticatedRepository<br/>• Automatic Header Injection<br/>• Credential Resolution & Caching<br/>• JSON Response Decoding"]:::data
        ConcreteRepos["PaymentRepository<br/>CredentialsRepository<br/>CardRepository<br/>RefundRepository<br/>InvoiceRepository"]:::data
        HMACSigner["HMACSigner (HMAC-SHA256 Request Signing)"]:::data
        NetClient["NetworkClientProtocol<br/>URLSessionNetworkClient"]:::data
        APIEndpoint["APIEndpoint (URLRequest Builder)"]:::data
        NetLogger["NetworkLogger (PII/Card Redaction)"]:::data
    end

    subgraph ExternalServices["External Dependencies & Frameworks"]
        CompanionLib["uInterfaceNative.xcframework<br/>(ApplePayProcessor)"]:::ext
        SystemWebKit["WebKit (WKWebView)"]:::ext
        UPaymentsBackend["UPayments API v1<br/>(sandboxapi / api.upayments.com)"]:::ext
    end

    %% Dependency & Interaction Flows
    UPayments --> PaymentRouter
    UPayments --> UseCases
    PaymentRouter -->|"Web Flow Routing"| WebFlowCoord
    PaymentRouter -->|"apple-pay Routing"| ApplePayHandler
    ApplePayHandler --> CompanionLib
    LegacyAdapter --> UseCases

    WebFlowCoord --> WebVC
    CardFlowCoord --> CardVC
    WebVC --> SystemWebKit

    UseCases --> ValidationEngine
    UseCases --> RepoProtocols

    ConcreteRepos -.->|"Implements"| RepoProtocols
    ConcreteRepos --> BaseRepo
    BaseRepo --> HMACSigner
    BaseRepo --> APIEndpoint
    BaseRepo --> NetClient
    NetClient --> NetLogger
    NetClient -->|"HTTPS Calls"| UPaymentsBackend
```

---

### 5.2 Architectural Invariants & Boundary Rules

1. **Zero-Network & Zero-UI Domain Layer**: `Sources/Domain/` never imports `UIKit`, `WebKit`, or networking clients. All domain logic depends strictly on repository interfaces (`PaymentRepositoryProtocol`, etc.).
2. **Pre-Flight Validation Mandate**: In-SDK default fallbacks are strictly prohibited. Every Use Case validates required fields (e.g., `amount > 0`, `currency`, `language`, `returnURL`, `cancelURL`) and fails fast with `NetworkError.validationFailed(reason:missingFields:)`.
3. **Pluggable Payment Routing**: The `PaymentRouter` decouples native handlers from web coordinators. Any payment source (`src == "apple-pay"`) is dynamically intercepted by its registered `PaymentMethodHandler`.
4. **Backward Compatibility**: Legacy interfaces (`PaymentGatewayImplementation.shared.paymentStoreUseCase` and `PaymentAPIManager`) are preserved via adapters that forward calls to modern Use Cases without changing public method signatures.

---

## 6. Main SDK Sequence Diagrams

### 6.1 Sequence Diagram: Web / Hosted Checkout (KNET & Credit Card)

```mermaid
sequenceDiagram
    autonumber
    actor Customer
    participant App as Merchant iOS App
    participant SDK as UPayments Facade
    participant Router as PaymentRouter
    participant UC as ProcessPaymentUseCase
    participant Repo as PaymentRepository
    participant API as UPayments API
    participant Coord as PaymentWebFlowCoordinator
    participant WebVC as PaymentWebViewController
    participant Gateway as Bank / Gateway 3DS

    Customer->>App: Taps "Pay with KNET / Card"
    App->>SDK: processPayment(request:from:completion:)
    SDK->>Router: routePayment(request:from:completion:)
    
    Note over Router: Checks registered handlers.<br/>Payment source is web-based (not "apple-pay")
    Router->>UC: execute(request:completion:)
    
    critical Pre-Flight Validation
        UC->>UC: Validate required fields (amount > 0, currency, returnURL, etc.)
    end

    UC->>Repo: processPayment(request:completion:)
    Repo->>API: POST /charge or /payment-request (Signed HMAC-SHA256)
    API-->>Repo: 200 OK (paymentURL returned)
    Repo-->>UC: Result.success(PaymentRequestResponse)
    UC-->>Router: Result.success(paymentURL)

    Router->>Coord: presentPaymentWebFlow(url:from:completion:)
    Coord->>WebVC: init(paymentURL, returnURL, cancelURL)
    Coord->>App: Present modally (UISheetPresentationController)
    WebVC->>Customer: Display hosted checkout sheet

    Customer->>Gateway: Enters card / PIN & authorizes 3DS
    Gateway-->>WebVC: Redirect to Return URL (with query params)

    Note over WebVC: WKNavigationDelegate intercepts redirect URL.<br/>Extracts paymentId, result, trackId, etc.
    WebVC->>Coord: notifyPaymentCompleted(transactionDetails)
    Coord->>WebVC: Dismiss sheet modally
    Coord-->>Router: PaymentResult(isSuccess: true, data: transactionDetails)
    Router-->>SDK: PaymentResult
    SDK-->>App: completion(.success(PaymentResult))
    App->>Customer: Display Order Confirmation
```

---

### 6.2 Sequence Diagram: Native Apple Pay via Companion SDK Binding

```mermaid
sequenceDiagram
    autonumber
    actor Customer
    participant App as Merchant iOS App
    participant SDK as UPayments Facade
    participant Router as PaymentRouter
    participant Handler as ApplePayPaymentHandler
    participant Companion as uInterfaceNative (ApplePayProcessor)
    participant PassKit as Apple PassKit
    participant Repo as PaymentRepository
    participant API as UPayments API

    Customer->>App: Taps Apple Pay button
    App->>SDK: processPayment(request [src: "apple-pay"]:from:completion:)
    SDK->>Router: routePayment(request:from:completion:)
    
    Note over Router: Matches ApplePayPaymentHandler<br/>(canHandle == true)
    Router->>Handler: authorizePayment(request:from:completion:)
    
    Handler->>Handler: Map products & totals to [ApplePaySummaryItem]
    Handler->>Companion: requestPayment(request:completion:)
    Companion->>PassKit: Present PKPaymentAuthorizationController

    PassKit->>Customer: Prompt Face ID / Touch ID Sheet
    Customer->>PassKit: Authenticates Biometrics
    PassKit-->>Companion: PKPaymentToken (Encrypted Cryptogram)
    
    Note over Companion: Deserializes paymentData UTF-8 JSON<br/>Maps to ApplePayPaymentTokenPayload
    Companion->>PassKit: completeAuthorization(status: .success)
    PassKit-->>Customer: Show "Done" Checkmark & Dismiss Sheet
    Companion-->>Handler: Result.success(ApplePayPaymentTokenPayload)

    Note over Handler: Serializes token into<br/>PaymentGatewayTokenModel (flat + nested keys)
    Handler->>Repo: processPayment(requestWithToken:completion:)
    Repo->>API: POST /charge (Token cryptogram payload)
    API-->>Repo: 200 OK (PaymentResult / TransactionDetails)
    Repo-->>Handler: Result.success(PaymentResult)
    Handler-->>Router: Result.success(PaymentResult)
    Router-->>SDK: Result.success(PaymentResult)
    SDK-->>App: completion(.success(PaymentResult))
    App->>Customer: Display In-App Success State
```

---

### 6.3 Sequence Diagram: Card Tokenization & Auto-Deduct Billing

```mermaid
sequenceDiagram
    autonumber
    actor Customer
    participant App as Merchant iOS App
    participant SDK as UPayments Facade
    participant CardUC as AddCustomerCardUseCase / AutoDeductUseCase
    participant CardCoord as CardWebFlowCoordinator
    participant Repo as CardRepository / PaymentRepository
    participant API as UPayments API

    rect rgb(240, 248, 255)
        Note over Customer, API: Phase 1: Card Tokenization (Save Card on File)
        Customer->>App: Selects "Save Card for Future Payments"
        App->>SDK: addCustomerCard(request:from:completion:)
        SDK->>CardUC: execute(request:completion:)
        CardUC->>Repo: addCustomerCard(request:completion:)
        Repo->>API: POST /add-card (HMAC Signed)
        API-->>Repo: 200 OK (Tokenization Web URL)
        Repo-->>CardUC: Tokenization URL
        CardUC->>CardCoord: presentCardWebFlow(url:from:completion:)
        CardCoord->>Customer: Present AddCardController Sheet
        Customer->>Customer: Enters Card Details & Completes 3DS OTP
        CardCoord-->>SDK: Card Added Successfully (Card Token Generated)
        SDK-->>App: completion(.success(CustomerCardDetails))
    end

    rect rgb(255, 248, 240)
        Note over Customer, API: Phase 2: Auto-Deduct (Automated Subscription / One-Click Charge)
        App->>SDK: autoDeductPayment(request [token, customerId, amount]:completion:)
        SDK->>CardUC: execute(request:completion:)
        CardUC->>Repo: autoDeductPayment(request:completion:)
        Repo->>API: POST /auto-deduct (Signed with Card Token)
        API-->>Repo: 200 OK (Charge Result)
        Repo-->>SDK: Result.success(PaymentResult)
        SDK-->>App: completion(.success(PaymentResult))
    end
```

---

## 7. Comparative Summary: Main SDK vs Companion SDK

| Architectural Dimension | Main SDK (`uInterfaceSDK`) | Companion SDK (`uInterfaceNative`) |
| :--- | :--- | :--- |
| **Primary Architectural Role** | Full-featured, turnkey payment gateway framework | Lightweight PassKit helper & token extraction library |
| **Layering Model** | Clean Architecture (Domain, Data, Presentation, Core) | Single-module service encapsulation |
| **Networking Responsibility** | Built-in (`URLSessionNetworkClient`, HMAC signer, endpoint mapping) | **Zero networking** (merchant or host SDK handles network calls) |
| **UI Presentation** | Modal `WKWebView` coordinators + native Apple Pay sheet | Apple-native `PKPaymentAuthorizationController` sheet only |
| **Supported Payment Rails** | KNET, Credit/Debit cards, Apple Pay, Recurring Auto-Deduct | Apple Pay only |
| **Pre-Flight Validation** | Strict domain validation engine (fails fast on missing fields) | Validates Apple Pay configuration and active wallet cards |
| **Token Handling** | Automatically serializes and transmits tokens to `/charge` | Extracts & returns typed `ApplePayPaymentTokenPayload` to caller |
| **Error Architecture** | `NetworkError` (typed status, code, validation fields) | `ApplePayError` (PassKit and authorization specific enums) |
| **CocoaPods Podspec** | `uInterfaceSDK.podspec` (links `uInterfaceNative.xcframework`) | `uInterfaceNative.podspec` (standalone pod) |
| **SPM Support** | `Package.swift` referencing binary targets | Standalone Swift Package |

---

## 8. Cross-Reference Index

- **Main SDK Merchant Integration Guide**: [`../iOS-SDK/docs/main-sdk.md`](file:///Users/siyahulhaq/Work/UPayments/SDKs/iOS-SDK/docs/main-sdk.md)
- **Companion SDK Merchant Integration Guide**: [`docs/companion-sdk.md`](file:///Users/siyahulhaq/Work/UPayments/SDKs/uInterfaceNative/docs/companion-sdk.md)
- **CocoaPods Publishing Guide**: [`docs/publishing-to-cocoapods.md`](file:///Users/siyahulhaq/Work/UPayments/SDKs/uInterfaceNative/docs/publishing-to-cocoapods.md)
