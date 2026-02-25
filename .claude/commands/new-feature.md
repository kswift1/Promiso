---
name: new-feature
description: 새로운 TCA Feature 생성 (Reducer + View + Tests)
---

# /new-feature $ARGUMENTS

새로운 TCA Feature를 생성합니다.

## 실행 순서

1. **implementer** 에이전트로 Feature 코드 생성
   - `{Name}Feature.swift` (State, Action, Reducer)
   - `{Name}View.swift` (SwiftUI View)

2. **test-writer** 에이전트로 테스트 코드 생성
   - `{Name}FeatureTests.swift`

3. **reviewer** 에이전트로 생성된 코드 검토

## 생성 위치

```
Projects/Features/{Name}Feature/
├── Sources/
│   ├── {Name}Feature.swift
│   └── {Name}View.swift
└── Tests/
    └── Sources/
        └── {Name}FeatureTests.swift
```

## 사용 예시

```bash
/new-feature NotificationSettings
/new-feature PrivacySettings
/new-feature AccountManagement
```

## 옵션

- `--skip-tests`: 테스트 생성 생략
- `--skip-review`: 코드 리뷰 생략

## 요구사항 입력

Feature 생성 시 다음 정보를 제공하면 더 정확한 코드가 생성됩니다:

- 화면의 목적
- 필요한 상태 (State)
- 사용자 인터랙션 (Action)
- 외부 의존성 (Client)
