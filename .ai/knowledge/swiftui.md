---
updated:
expires:
version:
source: https://developer.apple.com/documentation/swiftui
---

# SwiftUI / iOS 지식 베이스

> 이 파일은 `knowledge-updater` 에이전트가 자동으로 관리합니다.

## 현재 버전 정보

- **최신 iOS**: (검색 필요)
- **최신 Swift**: (검색 필요)
- **확인 일자**: -
- **출처**: [Apple Developer](https://developer.apple.com)

## Promiso 프로젝트 상태

- **Target iOS**: 18.0+
- **Swift 버전**: 6.0
- **Xcode**: (확인 필요)

## iOS 버전별 주요 기능 (AI 지식 기준)

### iOS 18 (2024)
- Control Center widgets
- Enhanced Charts
- App Intents 개선
- SwiftData 2.0

### iOS 26 (2025 예정)
- `.glassEffect()` - Glass Effect UI
- 새로운 Material 시스템
- Vision Pro 통합 개선

## Swift 버전별 주요 변경

### Swift 6 (2024)
- Complete concurrency checking
- Strict `Sendable` 적용
- Actor isolation 강화
- Data race safety 보장

## 자주 묻는 질문

### Q: iOS 26의 Glass Effect는 어떻게 사용하나요?
A:
```swift
if #available(iOS 26.0, *) {
    view.glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
} else {
    view.background(.ultraThinMaterial)
}
```

### Q: Swift 6의 Sendable 관련 에러는 어떻게 해결하나요?
A:
- 타입에 `Sendable` 프로토콜 준수 추가
- `@MainActor` 어노테이션 활용
- `@unchecked Sendable` 필요시 사용 (주의)

## 참고 자료

- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Swift Evolution](https://www.swift.org/swift-evolution/)
- [WWDC Videos](https://developer.apple.com/videos/)

---

*마지막 검색: 아직 검색되지 않음*
