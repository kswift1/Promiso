# PR 리뷰 자동 수정

현재 브랜치의 PR 리뷰를 수집하고, 수정이 필요한 항목을 선별해 승인 후 반영합니다.

> 먼저 `.ai/AI_WORKFLOW.md`를 읽고 따른다. 이 파일은 작업별 규칙만 정의한다.

## 참조
- 코드 스타일/아키텍처: `.ai/CONVENTIONS.md`
- 테스트 정책: `.ai/TEST_POLICY.md` (테스트 변경 시)
- 저장소: `kswift1/Promiso`

## 워크플로우

### Phase 1: 리뷰 수집 및 분석
1. `gh pr view --json number,title,url,headRefName,baseRefName`로 현재 PR 확인
2. `gh api repos/kswift1/Promiso/pulls/{pr}/comments --paginate`로 리뷰 조회
3. 최상위 코멘트(`in_reply_to_id == null`)만 액션 후보로 필터
4. 답글 중 아래 prefix가 있으면 이미 처리된 항목으로 간주
   - `완료:`
   - `스킵:`
   - `추후 진행 예정:`
5. 미처리 항목만 남기고 우선순위 분류: `critical > high > medium`

### Phase 2: 수정 필요 여부 판단
`.ai/CONVENTIONS.md`와 관련 `.ai/` 문서를 기준으로 각 리뷰를 분류:

**수정 진행**
- 버그/보안 이슈
- 프로토콜 conformance 누락
- 하드코딩 값 상수화
- 중복 코드 제거
- 컨벤션/아키텍처 위반

**스킵 또는 추후**
- 프로젝트 규칙에 없는 순수 스타일 선호
- 대규모 아키텍처 변경 필요
- 별도 PR로 분리해야 하는 작업
- 안전한 반영을 위해 필수는 아닌 테스트 추가 요청

#### 체크포인트 1: 사용자 확인
분석 결과를 표로 정리해 사용자에게 확인 요청:
```
| # | 우선순위 | 파일 | 내용 요약 | 판단 |
|---|---------|------|----------|------|
| 1 | critical | xxx.swift | ... | 수정 |
| 2 | medium | yyy.swift | ... | 스킵 |
```
사용자 승인 후에만 Phase 3로 진행.

### Phase 3: 수정 및 검증
각 승인된 수정 항목에 대해 순차 실행:
1. 관련 파일과 주변 컨텍스트 읽기
2. 최소 범위로 코드 수정
3. 검증은 `.ai/AI_WORKFLOW.md`의 구현(3단계) + 검증(4단계) 절차를 따른다

### Phase 4: 커밋 전 확인

#### 체크포인트 2: 사용자 확인
수정 완료 후 아래를 정리해 확인 요청:
```
## 변경 요약
- 수정한 리뷰 항목
- 스킵/추후 항목과 사유
- 변경 파일 목록
- 빌드/테스트 결과

## 커밋 예정
- fix: 수정 내용 1
- fix: 수정 내용 2

## 답글 예정
- 리뷰 #1: "완료: [SHA](링크)"
- 리뷰 #2: "스킵: 사유"
```

사용자 승인 전에는 `git add`, `git commit`, `git push`, GitHub 답글을 수행하지 않는다.

### Phase 5: 승인 후 후속 처리
사용자 승인 후 진행:
1. 리뷰 항목 단위 또는 논리 단위로 커밋
2. `git push`
3. 각 리뷰 코멘트에 답글:
   ```bash
   gh api repos/kswift1/Promiso/pulls/{pr}/comments/{id}/replies \
     -X POST -f body="완료: [SHA](https://github.com/kswift1/Promiso/commit/SHA)"
   ```

### Phase 6: 최종 요약
```
## PR 리뷰 처리 완료

### 완료
- [SHA] 수정 내용

### 스킵
- 사유: ...

### 추후 진행
- ...
```

## 답글 형식
- 완료: `완료: [SHA](https://github.com/kswift1/Promiso/commit/SHA)`
- 스킵: `스킵: {사유}`
- 추후: `추후 진행 예정: {사유}`
