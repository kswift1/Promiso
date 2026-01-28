---
updated:
expires:
version:
source: https://github.com/pointfreeco/swift-composable-architecture/releases
---

# TCA (The Composable Architecture) 지식 베이스

> 이 파일은 `knowledge-updater` 에이전트가 자동으로 관리합니다.

## 현재 버전 정보

- **최신 버전**: (검색 필요)
- **확인 일자**: -
- **출처**: [GitHub Releases](https://github.com/pointfreeco/swift-composable-architecture/releases)

## Promiso 프로젝트 상태

- **사용 중인 버전**: 1.22.2
- **업그레이드 필요**: (확인 필요)

## 주요 변경사항 (AI 지식 기준)

### 1.7+ (2024)
- `@ObservableState` 도입
- `@BindingState` deprecated
- Observation 프레임워크 통합

### 1.10+ (2024)
- Shared state 개선
- `@Shared` 매크로 도입

### 1.22+ (2025)
- Swift 6 concurrency 완전 지원
- `Sendable` 요구 강화
- iOS 18 최적화

## 자주 묻는 질문

### Q: @BindingState 대신 무엇을 사용하나요?
A: `@ObservableState`를 사용합니다. TCA 1.7부터 도입되었습니다.

### Q: .task { } 대신 무엇을 사용하나요?
A: `Effect.run { }` 또는 `.send()`를 사용합니다.

### Q: .fireAndForget { } 대신 무엇을 사용하나요?
A: `Effect.run { _ in ... }` (결과 무시)를 사용합니다.

## 마이그레이션 가이드

- [1.7 Migration Guide](https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7)
- [1.10 Migration Guide](https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.10)

---

*마지막 검색: 아직 검색되지 않음*
