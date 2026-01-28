---
updated: 2025-01-29
total_patterns: 0
---

# 파일 생성 패턴

> 반복적인 파일 생성 패턴을 추적합니다.
> 동일 구조의 파일이 3회 이상 생성되면 템플릿 Skill 대상입니다.

## 활성 패턴

| ID | 패턴 | 횟수 | Skill 상태 |
|----|------|------|-----------|
| - | (아직 감지된 패턴 없음) | - | - |

## 기존 템플릿 (Skill 대응됨)

### Feature 파일 세트
```
Projects/Features/{Name}Feature/
├── Sources/
│   ├── {Name}Feature.swift
│   └── {Name}View.swift
└── Tests/
    └── {Name}FeatureTests.swift
```
- **대응 Skill**: /new-feature, /new-screen

## 잠재적 패턴 (관찰 대상)

### Client 모듈
```
Projects/Clients/{Name}Client/
├── Sources/
│   ├── {Name}Client.swift
│   └── {Name}ClientLive.swift
└── Tests/
    └── {Name}ClientTests.swift
```
- **제안 Skill**: /new-client

### Shared 컴포넌트
```
Projects/Shared/Sources/UI/Components/
└── {Name}.swift
```
- **제안 Skill**: /new-component

### Firebase Functions
```
infra/firebase/functions/src/
├── {name}/
│   ├── index.ts
│   └── types.ts
└── index.ts (export 추가)
```
- **제안 Skill**: /new-function

---

## 패턴 상세

<!-- 감지된 패턴의 상세 정보가 여기에 추가됩니다 -->

### 템플릿

```markdown
### FILE-{ID}: {패턴명}

**생성 파일 구조**:
```
{directory}/
├── {file1}
├── {file2}
└── {file3}
```

- **첫 감지**: {날짜}
- **총 횟수**: {N}회
- **제안 Skill**: /{skill-name}
- **상태**: 🆕 제안됨 / ✅ 생성됨 / ❌ 거부됨
```
