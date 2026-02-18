# Localization 진행 현황

## 개요

- **지원 언어**: 한국어 (ko, 기본) + 영어 (en)
- **방식**: String Catalog (.xcstrings) + `String(localized:bundle:)`
- **문자열 관리**: `Projects/Shared/Sources/LocalizedStrings.swift` (중앙 집중)
- **번역 파일**: `Projects/Shared/Resources/Localizable.xcstrings`
- **작업 브랜치**: `feat/localization-infra`

## 전체 진행 상태

| 단계 | 상태 | 설명 |
|------|------|------|
| Phase 1: 인프라 | ✅ 완료 | xcstrings + Tuist 설정 + LocalizedStrings 마이그레이션 |
| Batch 1: 소형 Feature | ✅ 완료 | Auth, Notification, AppEntry, Personal |
| Batch 2: 중형 Feature | ✅ 완료 | Home, SharedFeature, Calendar |
| Batch 3: 중형 Feature | ⬜ 대기 | RootTab, Group |
| Batch 4: 대형 Feature | ⬜ 대기 | Settings |
| Batch 5: 기타 | ⬜ 대기 | Clients/Shared 내 잔여 문자열, Widget Extension |
| 언어 전환 기능 | ⬜ 대기 | 앱 내 언어 설정 UI + 전환 로직 |
| 영어 번역 검수 | ⬜ 대기 | 전체 영어 번역 품질 검수 |

## 커밋 이력

| 커밋 | 내용 | 변경 파일 |
|------|------|----------|
| `b4d54f8` | Phase 1: 인프라 구축 (xcstrings 62키, NSLocalizedString → String(localized:bundle:), CFBundleLocalizations) | 3개 |
| `3f29d0a` | Batch 1: Auth, Notification, AppEntry, Personal (47키 추가) | 12개 |
| `b2d39e5` | Batch 2: Home, SharedFeature, Calendar (대량 키 추가) | 36개 |

## Feature별 상세 현황

### ✅ 완료

| Feature | 파일 수 | 로컬라이징된 문자열 | 비고 |
|---------|---------|-----------------|------|
| AuthFeature | 2 | 7개 | 히어로 텍스트, 소셜 로그인 버튼 |
| NotificationCenterFeature | 1 | 8개 | 필터 displayTitle 추가 |
| AppEntryFeature | 8 | 25개 | 온보딩, 프로필 설정, 업데이트 알림 |
| PersonalFeature | 3 | 14개 | EventFilter.title 로컬라이징 |
| HomeFeature | 12 | 대량 | 시간대별 인사말, 랜덤 메시지, 섹션 헤더 |
| SharedFeature | 13 | 대량 | 약속 편집/상세, 위치 선택, 알림 권한, 개인 일정 |
| CalendarFeature | 4 | 대량 | 캘린더 헤더, 약속 카드, 권한 배너 |

### ⬜ 대기

| Feature | 예상 파일 수 | 예상 문자열 수 | 난이도 |
|---------|------------|-------------|--------|
| RootTabFeature | 4+ | ~40 (실 UI) | 중 (LivePromise 다수) |
| GroupFeature | 42 | ~35+ | 중 (가장 많은 파일) |
| SettingsFeature | 14 | ~195 | 대 (가장 많은 문자열) |

## 아키텍처

```
Projects/Shared/
├── Resources/
│   └── Localizable.xcstrings     ← String Catalog (ko/en)
└── Sources/
    └── LocalizedStrings.swift     ← 타입세이프 접근자

사용법:
  Text(LocalizedStrings.Common.ok)           // 단순 문자열
  Text(LocalizedStrings.Personal.photoCount(3))  // 포맷 문자열
  Text("키".localized)                       // 동적 키 접근
```

### 언어 전환 방식 (현재)

- **시스템 언어 기반**: iOS 설정 → 언어 변경 시 자동 전환
- 앱 내 언어 설정 UI 없음

### 언어 전환 기능 (계획)

앱 내에서 직접 언어를 변경할 수 있는 기능:

- **위치**: SettingsFeature (설정 → 언어)
- **필요 구현**:
  1. 언어 선택 UI (한국어/영어)
  2. 선택한 언어를 UserDefaults에 저장
  3. `LocalizedStrings.bundle`을 선택된 언어의 번들로 교체
  4. 앱 재시작 없이 UI 갱신 (또는 재시작 안내)
- **고려사항**:
  - iOS는 앱별 언어 설정 지원 (Settings → Promiso → Language)
  - 별도 구현 vs iOS 기본 기능 활용 결정 필요

## 주의사항

- Preview/Mock 데이터의 더미 문자열(이름, 장소 등)은 로컬라이징 대상 아님
- enum rawValue로 사용되는 한글은 `displayTitle` computed property로 분리
- `Bundle.module`은 Tuist 자동 생성 (Shared 프레임워크 번들)
- `Localizable.xcstrings`는 유효한 JSON이어야 함
