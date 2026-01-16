# PR 리뷰 자동 수정

현재 브랜치의 PR 리뷰를 자동으로 처리합니다.

## 참조
- 코드 스타일: `.gemini/styleguide.md` 파일 규칙 준수
- 빌드: `tuist build {Scheme}`
- 저장소: kswift1/Promiso

## 워크플로우

### Phase 1: 리뷰 수집 및 분석
1. `gh pr view --json number`로 현재 PR 번호 확인
2. `gh api repos/kswift1/Promiso/pulls/{pr}/comments`로 리뷰 조회
3. 최상위 코멘트(in_reply_to_id가 null) 필터
4. **리뷰 필요 여부 판단:**
   - 답글 중 "완료:"로 시작하는 것이 없으면 → 리뷰 필요
   - "완료:"로 시작하는 답글이 있으면 → 처리 완료로 간주
5. 우선순위 분류: critical > high > medium

### Phase 2: 수정 필요 여부 판단
`.gemini/styleguide.md` 기준으로 각 리뷰 분석:

**수정 진행:**
- 버그/보안 이슈
- 프로토콜 conformance 누락
- 하드코딩된 값 상수화
- 중복 코드 제거
- styleguide 위반 사항

**스킵:**
- 순수 스타일/코드 구조 선호도 (styleguide에 명시 안 된 경우)
- 대규모 아키텍처 변경 필요
- 별도 PR로 진행해야 하는 작업
- 테스트 추가 요청

#### ✅ 체크포인트 1: 사용자 확인
분석 결과를 테이블로 정리하여 사용자에게 확인 요청:
```
| # | 우선순위 | 파일 | 내용 요약 | 판단 |
|---|---------|------|----------|------|
| 1 | critical | xxx.swift | ... | 수정 |
| 2 | medium | yyy.swift | ... | 스킵 |
```
→ 사용자 승인 후 Phase 3 진행

### Phase 3: 수정 루프
각 수정 항목에 대해 순차 실행:
1. 관련 파일 읽기
2. 코드 수정 (Edit 도구 사용)
3. `tuist build {관련스킴}` 으로 빌드 확인
4. 빌드 실패 시 수정 재시도 (최대 2회)
5. 빌드 성공 시 커밋:
   ```bash
   git add {수정파일}
   git commit -m "fix: {수정내용}

   Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
   ```

### Phase 4: 커밋 확인 및 Push

#### ✅ 체크포인트 2: 사용자 확인
수정 완료 후 커밋 목록과 답글 내용을 정리하여 확인 요청:
```
## 커밋 목록
- [SHA1] fix: 수정 내용 1
- [SHA2] fix: 수정 내용 2

## 답글 예정
- 리뷰 #1: "완료: [SHA1](링크)"
- 리뷰 #2: "스킵: 사유"

Push 및 답글 진행할까요?
```
→ 사용자 승인 후 진행:
1. `git push`
2. 각 리뷰 코멘트에 답글:
   ```bash
   gh api repos/kswift1/Promiso/pulls/{pr}/comments/{id}/replies \
     -X POST -f body="완료: [SHA](https://github.com/kswift1/Promiso/commit/SHA)"
   ```

### Phase 5: 최종 요약
```
## PR 리뷰 처리 완료

### 완료
- [SHA] 수정 내용

### 스킵
- 사유: ...

### 추후 진행
- ...

---
새 리뷰가 추가되면 `/fix-reviews`를 다시 실행하세요.
```

## 답글 형식
- 완료: `완료: [SHA](https://github.com/kswift1/Promiso/commit/SHA)`
- 스킵: `스킵: {사유}`
- 추후: `추후 진행 예정: {사유}`
