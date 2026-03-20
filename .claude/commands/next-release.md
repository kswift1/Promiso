---
name: next-release
description: 릴리스 완료 후 다음 버전 준비 (머지, 태그, 브랜치, 버전 업데이트)
---

# /next-release $ARGUMENTS

릴리스 완료 후 main 머지 → 다음 버전 준비까지 자동으로 수행합니다.

## 인자

- `$ARGUMENTS`: 다음 버전 (예: `1.3.0`)
  - 생략 시 커밋 분석 기반으로 자동 제안

## 실행 순서

### 1. 현재 상태 파악 (자동)

다음 정보를 수집한다:

- 현재 버전: `Tuist/ProjectDescriptionHelpers/AppConfig.swift`의 `marketingNumber`
- 현재 release 브랜치: `release/v{현재버전}`
- 기존 태그 목록: `git tag --list 'v*'`
- release → main 머지 여부: `git log main..release/v{현재버전} --oneline`

### 2. release → main 머지 (자동)

release 브랜치가 main에 아직 머지되지 않았으면:

```bash
git checkout main
git merge release/v{현재버전} --no-ff -m "chore: release/v{현재버전} → main 머지"
git push origin main
```

이미 머지 완료 상태면 스킵한다.

### 3. 릴리스 태그 생성 (자동)

`v{현재버전}` 태그가 없으면 main의 머지 커밋에 태그를 생성한다:

```bash
git tag v{현재버전}
git push origin v{현재버전}
```

이미 존재하면 스킵한다.

### 4. 다음 버전 제안 (멈춤 — 사용자 확인)

이전 태그 이후 커밋을 분석하여 다음 버전을 제안한다:

| 조건 | 제안 |
|------|------|
| `feat:` 커밋이 있음 | minor 버전 증가 (예: 1.2.1 → 1.3.0) |
| `fix:` 커밋만 있음 | patch 버전 증가 (예: 1.2.1 → 1.2.2) |
| 인자로 버전이 주어짐 | 해당 버전 사용 |

사용자에게 다음을 보여주고 확인받는다:

```
현재 버전: v1.2.1
제안 버전: v1.3.0 (이유: feat 커밋 N개 감지)

이 버전으로 진행할까요? (다른 버전 입력 가능)
```

> **반드시 사용자 응답을 받은 후 다음 단계로 진행한다.**

### 5. release 브랜치 생성 & 버전 업데이트 (자동)

main에서 새 release 브랜치를 생성하고 버전을 업데이트한다:

```bash
git checkout -b release/v{다음버전} main
```

`Tuist/ProjectDescriptionHelpers/AppConfig.swift`의 `marketingNumber`를 변경:

```swift
// before
public static let marketingNumber: String = "{현재버전}"
// after
public static let marketingNumber: String = "{다음버전}"
```

### 6. 초기 커밋 & 푸시 (자동)

```bash
git add Tuist/ProjectDescriptionHelpers/AppConfig.swift
git commit -m "chore: v{다음버전} 개발 시작"
git push -u origin release/v{다음버전}
```

### 7. 이전 release 브랜치 정리 (자동 — 선택)

머지 완료된 이전 release 브랜치 삭제 여부를 묻는다:

```
release/v{현재버전} 브랜치를 삭제할까요? (로컬 + 리모트)
```

- 승인 시: 로컬 & 리모트 모두 삭제
- 거부 시: 스킵

### 8. 완료 요약

최종 상태를 출력한다:

```
✅ 완료
- 태그: v{현재버전} 생성됨
- 브랜치: release/v{다음버전} (현재 브랜치)
- 버전: {다음버전}
- 정리: release/v{현재버전} 삭제됨/유지됨
```

## 사용 예시

```bash
/next-release          # 커밋 분석 기반 버전 자동 제안
/next-release 1.3.0    # 직접 버전 지정
```
