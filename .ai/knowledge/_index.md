# 지식 베이스 인덱스

> 이 디렉토리는 `knowledge-updater` 에이전트가 검색한 정보를 캐싱합니다.
> 중복 검색을 방지하고, 검증된 정보를 재사용합니다.

## 캐시 파일 목록

| 파일 | 기술 | 버전 | TTL | 최종 업데이트 | 만료일 | 상태 |
|------|------|------|-----|--------------|--------|------|
| [swiftui.md](./swiftui.md) | SwiftUI / iOS 26 | iOS 26 / Swift 6 | 3개월 | 2025-01-29 | 2025-04-29 | ✅ |
| [tca.md](./tca.md) | TCA (Composable Architecture) | 1.23.1 | 2주 | 2025-01-29 | 2025-02-12 | ✅ |
| [firebase.md](./firebase.md) | Firebase iOS SDK | 12.7.0 | 1개월 | 2025-01-29 | 2025-02-28 | ✅ |
| [tuist.md](./tuist.md) | Tuist | 4.x | 1개월 | 2025-01-29 | 2025-04-29 | ✅ |

## 주요 업데이트 내용 (2025-01-29)

### SwiftUI / iOS 26
- WWDC 2025 Liquid Glass 디자인 시스템 완전 정리
- GlassEffectContainer API 상세 문서화
- Foundation Models Framework (On-Device AI) 추가
- WebKit for SwiftUI 추가
- Backward Compatibility 패턴 정리

### TCA 1.23.1
- 2025년 릴리즈 요약 (1.17 ~ 1.23)
- @ObservableState Swift 6.2 개선사항
- Effect.run 성능 최적화 가이드
- Deprecated API 정리 (@BindingState, .task, .fireAndForget)

### Firebase iOS SDK 12.7.0
- Firebase AI Logic (구 Vertex AI) 신규 기능
- Dynamic Links 종료 안내 (2025년 8월)
- Firestore Swift Codable 상세 가이드
- 비용 최적화 팁

### Tuist 4.x
- Dependencies.swift → Package.swift 마이그레이션
- Back Market 성능 최적화 사례 (2025)
- 캐시 명령어 변경 (tuist cache warm → tuist cache)

---

## 사용 방법

### 자동 (권장)
`knowledge-updater` 에이전트가 자동으로 캐시를 확인하고 업데이트합니다.

### 수동 갱신
특정 기술의 정보를 강제로 갱신하려면:
```
"TCA 최신 정보 다시 검색해줘" (캐시 무시)
```

## 신선도 정책

| 기술 | TTL | 이유 |
|------|-----|------|
| TCA | 2주 | Point-Free 월 1-2회 릴리즈 |
| Firebase | 1개월 | Google 월간 릴리즈 |
| SwiftUI/iOS | 3개월 | Apple WWDC 연간 업데이트 |
| Tuist | 1개월 | 활발한 오픈소스 개발 |

## 캐시 파일 형식

```yaml
---
updated: YYYY-MM-DD      # 마지막 업데이트
expires: YYYY-MM-DD      # 만료일
version: X.X.X           # 확인된 최신 버전
source: URL              # 정보 출처
---
```

## 주의사항

- 캐시 파일을 직접 수정하지 마세요
- `knowledge-updater` 에이전트가 자동으로 관리합니다
- 잘못된 정보 발견 시 해당 파일 삭제 후 재검색 요청
