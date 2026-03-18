---
updated: 2026-02-25
expires: 2026-05-25
version: iOS 18 / iOS 26
source: https://developer.apple.com/documentation/vision/vnrecognizetextrequest
---

# iOS OCR + NLP + Share Extension 지식 베이스

## 현재 버전 정보
- **확인 일자**: 2026-02-25
- **대상 iOS**: 18.0+ (Promiso 타겟), iOS 26 (최신)
- **출처**: Apple Developer Documentation, WWDC24/25

---

## 1. iOS Vision Framework OCR

### 두 가지 API 비교

| 항목 | 구 API (iOS 13+) | 신 API (iOS 18+) |
|------|-----------------|-----------------|
| 클래스 | `VNRecognizeTextRequest` | `RecognizeTextRequest` |
| 패턴 | 콜백 기반 | async/await |
| 반환 | `[VNRecognizedTextObservation]` | `[RecognizedTextObservation]` |
| Swift 6 | 부분 지원 | 완전 지원 |

### iOS 18+ 신규 API (RecognizeTextRequest)

```swift
// iOS 18+ 신규 async/await API
import Vision

func recognizeText(from image: CGImage) async throws -> [String] {
    var request = RecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.recognitionLanguages = [
        Locale.Language(identifier: "ko-KR"),
        Locale.Language(identifier: "en-US")
    ]
    request.usesLanguageCorrection = true

    let observations = try await request.perform(on: image)
    return observations.compactMap { $0.topCandidates(1).first?.string }
}
```

### iOS 13+ 구 API (VNRecognizeTextRequest) - 현재 Promiso 타겟 기준

```swift
import Vision

func recognizeText(from cgImage: CGImage) async -> [String] {
    return await withCheckedContinuation { continuation in
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                continuation.resume(returning: [])
                return
            }
            let strings = observations.compactMap {
                $0.topCandidates(1).first?.string
            }
            continuation.resume(returning: strings)
        }
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["ko-KR", "en-US"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage)
        try? handler.perform([request])
    }
}
```

### 한국어 지원

- **iOS 16+**: 한국어(ko-KR) 공식 지원 추가 (WWDC22에서 발표)
- **지원 언어 수**: iOS 18 기준 18개 언어
- **지원 확인 방법**:
  ```swift
  let languages = try VNRecognizeTextRequest.supportedRecognitionLanguages(
      for: .accurate, revision: VNRecognizeTextRequestRevision3
  )
  // "ko-KR"이 포함되어 있음 (iOS 16+)
  ```
- **한국어 특이사항**: 세로 쓰기 텍스트는 Live Text(DataScannerViewController)가 더 잘 처리

### Vision Framework vs Live Text (VisionKit)

| 항목 | Vision Framework | Live Text (VisionKit) |
|------|-----------------|----------------------|
| 클래스 | `VNRecognizeTextRequest` | `DataScannerViewController` |
| 용도 | 정적 이미지 처리 | 실시간 카메라 스캔 |
| 제어 수준 | 완전한 커스터마이징 | 제한적 (UI 내장) |
| 세로 텍스트 | 미지원 | 지원 (동아시아 언어) |
| iOS 요구 | iOS 13+ | iOS 16+ |
| 비동기 | async/await (iOS 18+) | 내장 처리 |
| Share Extension | 사용 가능 | 사용 불가 (카메라 필요) |

### 성능 및 정확도

- `.accurate` vs `.fast`: 약속 정보 추출에는 `.accurate` 권장
- `minimumTextHeight`: 0.02 기본값, 낮을수록 작은 글씨 인식
- `customWords`: 특정 단어 힌트 제공 가능 (장소명 등)
- 신뢰도 임계값: `confidence > 0.8` 권장

---

## 2. 자연어 처리 (NLP)

### NaturalLanguage Framework vs NSLinguisticTagger

| 항목 | NaturalLanguage (권장) | NSLinguisticTagger (Deprecated) |
|------|----------------------|--------------------------------|
| iOS | 12+ | iOS 5+ (iOS 17 deprecated) |
| Swift | Modern API | 레거시 |
| 한국어 | 지원 | 제한적 |
| 상태 | 현재 사용 권장 | Deprecated, 사용 금지 |

### NLTagger 기본 사용 (Named Entity Recognition)

```swift
import NaturalLanguage

func extractEntities(from text: String) -> [String: NLTag] {
    let tagger = NLTagger(tagSchemes: [.nameType])
    tagger.string = text

    var entities: [String: NLTag] = [:]
    let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]

    tagger.enumerateTags(
        in: text.startIndex..<text.endIndex,
        unit: .word,
        scheme: .nameType,
        options: options
    ) { tag, range in
        if let tag, [.personalName, .placeName, .organizationName].contains(tag) {
            entities[String(text[range])] = tag
        }
        return true
    }
    return entities
}
```

### 한국어 날짜/시간 파싱 전략

#### NSDataDetector - 구조화된 날짜 형식만 처리

```swift
// "2/28 오후 7시", "2025-02-28" 등 명확한 형식에 효과적
// "다음주 토요일", "내일 오후 3시" 등 상대적 표현은 처리 불가

let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))

for match in matches {
    if let date = match.date {
        print(date) // 파싱된 날짜
    }
}
```

**NSDataDetector 한국어 지원 범위:**
- "2025년 2월 28일" - 인식 가능
- "2/28 오후 7시" - 부분 인식 (날짜는 가능, 시간은 한국어 표기 불안정)
- "다음주 토요일" - 인식 불가
- "내일 저녁 7시" - 인식 불가
- "오후 3시" 단독 - 불안정

#### 한국어 상대적 날짜 파싱 - Custom 구현 필요

```swift
// 정규표현식 기반 한국어 날짜 파싱
struct KoreanDateParser {
    // "다음주 토요일", "이번주 금요일"
    static let relativeWeekPattern = #/(?P<relative>이번주|다음주|이번\s*주|다음\s*주)\s*(?P<weekday>월|화|수|목|금|토|일)요일/#

    // "내일", "모레", "오늘"
    static let relativeDayPattern = #/(?P<day>오늘|내일|모레|글피)/#

    // "오전/오후 N시 [N분]"
    static let timePattern = #/(?P<ampm>오전|오후|저녁|밤|새벽|아침)?\s*(?P<hour>\d{1,2})시\s*(?:(?P<minute>\d{1,2})분)?/#

    // "N월 N일"
    static let absoluteDatePattern = #/(?P<month>\d{1,2})월\s*(?P<day>\d{1,2})일/#

    static func parse(_ text: String) -> DateComponents? {
        // 구현...
    }
}
```

#### Foundation Models Framework (iOS 26+ 전용) - 최강 옵션

```swift
import FoundationModels

// iOS 26+ Apple Intelligence 기기에서만 사용 가능
@Generable
struct PromiseInfo: Equatable {
    @Guide(description: "약속 제목")
    var title: String

    @Guide(description: "날짜 (ISO 8601 형식, 예: 2025-03-01)")
    var date: String?

    @Guide(description: "시간 (HH:mm 형식, 예: 19:00)")
    var time: String?

    @Guide(description: "장소명")
    var location: String?
}

func extractPromiseInfo(from text: String) async throws -> PromiseInfo? {
    let model = SystemLanguageModel(useCase: .contentTagging)
    guard model.availability == .available else { return nil }

    let session = LanguageModelSession(model: model)
    return try await session.respond(
        to: "다음 텍스트에서 약속 정보를 추출해주세요: \(text)",
        generating: PromiseInfo.self
    )
}
```

### NER 장소명 추출 한국어 지원 현황

- `NLTagger` + `.nameType`: 한국어 장소명 추출 **부분 지원**
- 한국어 고유명사 인식률이 영어보다 낮음
- 도로명 주소("강남구 테헤란로")보다 랜드마크("강남역", "홍대입구")에 더 효과적
- 보완: 사전 기반 장소 목록 + NLTagger 조합 권장

---

## 3. Share Extension

### 기본 구조

```
Share Extension Target
├── ShareViewController.swift   # UIViewController 서브클래스
├── ShareView.swift            # SwiftUI View
└── Info.plist                 # NSExtension 설정
```

### SwiftUI 기반 Share Extension 구현

```swift
// ShareViewController.swift
import UIKit
import SwiftUI

class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        guard
            let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
            let itemProvider = extensionItem.attachments?.first
        else {
            close()
            return
        }

        let hostingController = UIHostingController(
            rootView: ShareView(
                itemProvider: itemProvider,
                extensionContext: extensionContext
            )
        )
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        hostingController.didMove(toParent: self)
    }

    func close() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
```

### 텍스트 + 이미지 수신

```swift
import UniformTypeIdentifiers

// iOS 16+ UTType 사용 권장
func loadContent(from itemProvider: NSItemProvider) async {
    // 이미지 수신
    if itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
        if let image = try? await itemProvider.loadItem(forTypeIdentifier: UTType.image.identifier) as? UIImage {
            // OCR 처리
        }
    }

    // 텍스트 수신
    if itemProvider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
        if let text = try? await itemProvider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String {
            // 텍스트 파싱
        }
    }

    // URL 수신
    if itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
        if let url = try? await itemProvider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
            // URL 처리
        }
    }
}
```

### App Group을 통한 데이터 공유

```swift
// 공유 UserDefaults (App Group)
let sharedDefaults = UserDefaults(suiteName: "group.com.promiso.app")

// Share Extension에서 저장
sharedDefaults?.set(extractedText, forKey: "pendingPromiseText")
sharedDefaults?.set(Date(), forKey: "pendingPromiseDate")

// 메인 앱에서 읽기 (onOpenURL 또는 onAppear)
if let text = sharedDefaults?.string(forKey: "pendingPromiseText") {
    // 처리 후 삭제
    sharedDefaults?.removeObject(forKey: "pendingPromiseText")
}
```

### @AppStorage + App Group

```swift
// SwiftUI에서 App Group UserDefaults 사용
@AppStorage("pendingPromiseText", store: UserDefaults(suiteName: "group.com.promiso.app"))
var pendingPromiseText: String = ""
```

### Info.plist 설정 (NSExtensionActivationRule)

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionAttributes</key>
    <dict>
        <key>NSExtensionActivationRule</key>
        <dict>
            <!-- 이미지 또는 텍스트 허용 -->
            <key>NSExtensionActivationSupportsImageWithMaxCount</key>
            <integer>1</integer>
            <key>NSExtensionActivationSupportsText</key>
            <true/>
            <key>NSExtensionActivationSupportsWebURLWithMaxCount</key>
            <integer>1</integer>
        </dict>
    </dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.share-services</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).ShareViewController</string>
</dict>
```

### 데이터 전달 방식 비교

| 방식 | 장점 | 단점 | 권장 여부 |
|------|------|------|----------|
| App Group UserDefaults | 간단, 즉시 사용 | 용량 제한 (512KB), 이미지 불가 | 텍스트 데이터에 권장 |
| App Group FileManager | 대용량 가능, 이미지 저장 가능 | 직접 파일 관리 | 이미지에 권장 |
| Universal Links (URL Scheme) | 앱 자동 오픈 | 보안 설정 복잡 | 딥링크 조합 시 |
| CoreData/SwiftData | 복잡한 데이터 | 설정 복잡 | 앱 내 영구 저장 |

### Swift 6 주의사항

```swift
// NSItemProvider는 non-Sendable → Swift 6에서 주의
// nonisolated 사용 또는 @preconcurrency 활용

nonisolated func loadContent(from itemProvider: NSItemProvider) async {
    // NSItemProvider 사용
}
```

---

## 4. iOS 18+ 최신 API

### TransferRepresentation (iOS 16+)

```swift
// Transferable 프로토콜 구현 (ShareLink용)
struct PromiseInfo: Transferable {
    var title: String
    var date: Date?

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
        ProxyRepresentation(exporting: \.title)
    }
}

// ShareLink 사용
ShareLink(item: promise, preview: SharePreview(promise.title))
```

### ShareLink (iOS 16+)

```swift
// SwiftUI ShareLink - 앱 내 공유 시트
ShareLink(
    item: URL(string: "https://promiso.app/promise/123")!,
    subject: Text("약속 공유"),
    message: Text("강남에서 3시에 만나요!")
)
```

---

## Promiso 프로젝트 적용 권장 아키텍처

### OCR 파이프라인

```
이미지 입력 (Share Extension)
    ↓
VNRecognizeTextRequest (iOS 18: RecognizeTextRequest)
    ↓ ko-KR + en-US
텍스트 추출
    ↓
파싱 레이어
    ├── NSDataDetector (절대 날짜: "2/28 오후 7시")
    ├── KoreanDateParser (상대 날짜: "다음주 토요일")
    ├── NLTagger (장소명 NER)
    └── Foundation Models (iOS 26+ 기기: 통합 처리)
    ↓
PromiseInfo 구조체
    ↓
App Group UserDefaults
    ↓
메인 앱 (약속 생성 화면 자동 채우기)
```

### 권장 구현 우선순위

1. **1단계**: VNRecognizeTextRequest (iOS 18+ API) + NSDataDetector
2. **2단계**: Custom 한국어 날짜 파서 (정규표현식)
3. **3단계**: NLTagger 장소명 추출
4. **4단계**: Foundation Models 통합 (iOS 26+ 조건부)

---

## 자주 묻는 질문

### Q: Share Extension에서 Vision OCR 사용 가능한가?
A: 가능합니다. Share Extension은 별도 프로세스이지만 Vision Framework는 Extension에서 완전히 사용 가능합니다. 단, 메모리 제한(약 120MB)에 주의해야 합니다.

### Q: NSDataDetector가 "오후 7시" 한국어를 인식하나?
A: 불안정합니다. "2월 28일 오후 7시"처럼 완전한 형식은 인식 가능하지만, "오후 7시" 단독이나 "다음주 토요일"은 인식하지 못합니다. Custom 정규표현식 파서가 필요합니다.

### Q: Foundation Models는 언제 사용해야 하나?
A: iOS 26+ + Apple Intelligence 지원 기기(iPhone 15 Pro 이상)에서만 사용 가능합니다. Promiso 타겟(iOS 18+)에서는 #available 분기 필수입니다.

### Q: Share Extension과 Main App 간 이미지 공유 방법은?
A: App Group FileManager를 사용합니다. UserDefaults는 텍스트만 가능하고, 이미지는 파일로 저장 후 경로를 공유해야 합니다.
