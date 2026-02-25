---
name: new-screen
description: 새로운 화면 생성 (Feature + UI 디자인 포함)
---

# /new-screen $ARGUMENTS

새로운 화면을 생성합니다. Feature 생성과 함께 UI 디자인도 포함됩니다.

## 실행 순서

1. **implementer** 에이전트로 Feature + View 코드 생성
   - Feature: TCA Reducer (Namespace 패턴)
   - View: iOS 26 Glass Effect + Aurora Background + Fallback

2. **test-writer** 에이전트로 테스트 코드 생성

3. **reviewer** 에이전트로 전체 검토

## 생성 위치

```
Projects/Features/{Name}Feature/
├── Sources/
│   ├── {Name}Feature.swift
│   ├── {Name}View.swift
│   └── Components/           # 필요시 하위 컴포넌트
│       └── {Component}View.swift
└── Tests/
    └── Sources/
        └── {Name}FeatureTests.swift
```

## 사용 예시

```bash
/new-screen Settings
/new-screen ProfileEdit
/new-screen GroupDetail
```

## UI 디자인 가이드

### 기본 적용 사항
- Glass Effect 배경
- pmindigo 컬러 팔레트
- 적절한 Spacing (Theme.swift)
- Dynamic Type 지원
- 다크모드 대응

### 레이아웃 패턴
- 상단: NavigationBar 또는 Header
- 중앙: ScrollView 또는 List
- 하단: 액션 버튼 (필요시)

## 옵션

- `--simple`: 기본 구조만 생성 (UI 최소화)
- `--with-navigation`: NavigationStack 포함
