---
name: release-notes
description: 릴리스 노트 자동 생성
---

# /release-notes $ARGUMENTS

릴리스 노트를 생성합니다.

## 인자

- `$ARGUMENTS`: 대상 버전 (예: `v1.2.1`)
  - 생략 시 최신 `release/` 브랜치 기준으로 자동 감지

## 실행 순서

### 1. 버전 범위 파악

이전 버전 태그와 대상 `release/` 브랜치 사이의 커밋을 수집한다.

```bash
git log {이전버전태그}..release/{대상버전} --oneline
```

### 2. 커밋 분류

수집된 커밋을 분류한다:

| 포함 | 제외 |
|------|------|
| `feat:` — 새 기능 | `ci:` — CI/CD |
| `fix:` — 사용자 체감 버그 수정 | `chore:` — 설정 변경 |
| `refactor:` — 사용자에게 보이는 변경 | `docs:` — 문서 |
| | `test:` — 테스트 |
| | `refactor:` — 내부만 변경 |

### 3. 톤 가이드 적용

`RELEASE_NOTES/TONE_GUIDE.md`를 읽고 규칙을 따른다:

- 사용자 관점, 경어체
- 기능 중심 서술, 한 기능당 1-2줄
- 기술 용어 사용하지 않음
- Pro 기능 먼저 배치

### 4. 파일 생성

`RELEASE_NOTES/{버전}.md` 파일을 생성한다.

이전 버전 노트(`RELEASE_NOTES/` 내 가장 최근 파일)를 참고하여 톤과 형식을 일관되게 유지한다.

### 5. 사용자 확인

생성된 노트를 사용자에게 보여주고 수정 사항을 확인받는다.

## 사용 예시

```bash
/release-notes v1.2.1
/release-notes v1.3.0
/release-notes          # 최신 release/ 브랜치 자동 감지
```
