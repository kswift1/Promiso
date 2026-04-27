# Notion FAQ 관리 가이드 (⚠️ 구 버전, 참고용)

> **현재 운영 기준**: FAQ는 `infra/rust-backend/migrations/017_faq_table.sql`로 생성된 Postgres `faqs` 테이블에서 관리됩니다.
> Notion 기반 경로(Firebase Functions + `NOTION_FAQ_API_KEY`)는 더 이상 사용하지 않습니다.
>
> **시드 운영 메모**:
> - `017_faq_table.sql`의 `INSERT` 문은 Dev/Stage/Prod 모든 환경에 동일하게 적용된다.
> - Prod에서만 문구/순서를 바꾸려면 이 마이그레이션을 수정하지 말고, 별도 admin 도구(또는 수동 SQL)로 Prod DB에 덮어쓴다.
> - 신규 FAQ 추가/수정은 admin 도구가 준비되기 전까지 `psql`로 직접 반영하고, 변경 이력을 PR 본문에 기록한다.
>
> 아래 내용은 Notion 기반 구현 당시 가이드로, Notion 워크스페이스 백업 등 히스토리 확인 목적으로만 참조한다.

## 개요

Promiso 앱의 FAQ는 Notion 데이터베이스에서 관리됩니다. 이를 통해 개발자가 아닌 팀원도 쉽게 FAQ를 추가/수정할 수 있습니다.

## Notion Database 구조

### Database ID
```
3029e4970675812ca3d6c852867858a2
```

### 속성 (Properties)

| 속성명 | 타입 | 설명 | 필수 |
|--------|------|------|------|
| `Question` | Title | FAQ 질문 | ✅ |
| `Answer` | Rich Text | FAQ 답변 | ✅ |
| `Category` | Select | 카테고리 (그룹, 알림, 약속, 계정 등) | ❌ |
| `Order` | Number | 정렬 순서 (낮을수록 먼저 표시) | ❌ |
| `Active` | Checkbox | 활성화 여부 (체크된 항목만 앱에 표시) | ✅ |

### Category 옵션
- `그룹` - 그룹 관련 FAQ
- `알림` - 알림/푸시 관련 FAQ
- `약속` - 약속 생성/관리 관련 FAQ
- `계정` - 계정/로그인 관련 FAQ

## Notion Integration 설정

### 1. Integration 생성
1. [Notion Integrations](https://www.notion.so/my-integrations) 접속
2. "New integration" 클릭
3. 이름: `Promiso FAQ`
4. Capabilities: **Read content**, **Insert content**, **Update content** 체크

### 2. Database 연결
1. FAQ Database 페이지 열기
2. 우측 상단 `...` > `Connections` > `Promiso FAQ` 추가

### 3. API Key 설정
- API Key는 `ntn_`으로 시작
- xcconfig 파일에 `NOTION_API_KEY` 설정

## API 사용법

### 환경 변수
```bash
API_KEY="ntn_xxxxx"
DB_ID="3029e4970675812ca3d6c852867858a2"
```

### FAQ 목록 조회 (Read)
```bash
curl -X POST "https://api.notion.com/v1/databases/${DB_ID}/query" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{
    "filter": {
      "property": "Active",
      "checkbox": { "equals": true }
    },
    "sorts": [
      { "property": "Order", "direction": "ascending" }
    ]
  }'
```

### FAQ 추가 (Create)
```bash
curl -X POST "https://api.notion.com/v1/pages" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{
    "parent": { "database_id": "'"${DB_ID}"'" },
    "properties": {
      "Question": {
        "title": [{ "text": { "content": "질문 내용" } }]
      },
      "Answer": {
        "rich_text": [{ "text": { "content": "답변 내용" } }]
      },
      "Category": {
        "select": { "name": "그룹" }
      },
      "Order": { "number": 1 },
      "Active": { "checkbox": true }
    }
  }'
```

### FAQ 수정 (Update)
```bash
PAGE_ID="페이지-uuid"

curl -X PATCH "https://api.notion.com/v1/pages/${PAGE_ID}" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{
    "properties": {
      "Answer": {
        "rich_text": [{ "text": { "content": "수정된 답변" } }]
      }
    }
  }'
```

### FAQ 비활성화 (Soft Delete)
```bash
curl -X PATCH "https://api.notion.com/v1/pages/${PAGE_ID}" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{
    "properties": {
      "Active": { "checkbox": false }
    }
  }'
```

### FAQ 삭제 (Archive)
```bash
curl -X PATCH "https://api.notion.com/v1/pages/${PAGE_ID}" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{ "archived": true }'
```

## 앱 코드 구조

### FAQClient.swift
```
Projects/Clients/Sources/Clients/FAQClient.swift
```

- Notion API 호출
- Response를 `FAQModel`로 변환
- `@Dependency(\.faqClient)`로 주입

### FAQFeature.swift
```
Projects/Features/SettingsFeature/Sources/Support/FAQFeature.swift
```

- TCA Reducer
- 카테고리 필터링
- 펼침/접힘 상태 관리

### 설정 파일
```
Config/Dev.xcconfig
Config/Stage.xcconfig
Config/Prod.xcconfig
```
- `NOTION_API_KEY` 설정

```
Projects/Shared/Sources/Constants/AppConstants.swift
```
- `notionFAQDatabaseId` 상수

## 문제 해결

### 워크스페이스 변경 시 체크리스트

Notion 워크스페이스를 변경한 경우 다음을 모두 확인하세요:

1. **Secret Manager 업데이트** (가장 흔한 원인)
   ```bash
   # Firebase Secret Manager에서 NOTION_FAQ_API_KEY를 새 워크스페이스의 키로 업데이트
   firebase functions:secrets:set NOTION_FAQ_API_KEY
   # 새 워크스페이스 Integration의 API 키 (ntn_xxx...) 입력
   ```

2. **Integration → Database 연결 확인**
   - 새 워크스페이스에서 FAQ Database 페이지 열기
   - 우측 상단 `...` > `Connections` > Integration 추가
   - Integration이 해당 Database에 접근 권한이 있어야 함

3. **Database 속성명 일치 확인**
   - 새 Database의 속성명이 정확히 `Question`, `Answer`, `Category`, `Order`, `Active`인지 확인
   - 속성명이 다르면 `faq.ts`의 filter/sort 및 데이터 변환 코드 수정 필요

4. **코드 내 Database ID 업데이트** (3곳)
   - `Projects/Shared/Sources/Constants/AppConstants.swift` → `defaultConfig.notionFAQDatabaseId`
   - `Projects/Clients/Sources/Clients/AppConfigClient.swift` → Remote Config defaults
   - `infra/firebase/remoteconfig.template.json` → `notionFAQDatabaseId`

5. **Firebase Remote Config 배포**
   ```bash
   firebase deploy --only remoteconfig
   ```

6. **Firebase Functions 재배포** (Secret 변경 시 필수)
   ```bash
   firebase deploy --only functions:getFAQs
   ```

### 401 Unauthorized
- `NOTION_FAQ_API_KEY`가 유효한지 확인
- 키가 새 워크스페이스의 Integration에서 발급된 것인지 확인

### 403 Forbidden
- Integration이 Database에 연결되었는지 확인
- Integration의 Capabilities에 **Read content** 권한이 있는지 확인

### 404 Not Found
- **가장 흔한 원인**: API 키가 다른 워크스페이스의 키 (워크스페이스 변경 후 Secret Manager 미갱신)
- Database ID가 올바른지 확인 (URL에서 추출)
- Notion URL: `https://notion.so/{database_id}?v=...`
- Integration이 해당 Database에 연결(Connection)되어 있는지 확인

### 400 Bad Request
- Database 속성명이 코드와 일치하는지 확인
- 필수 속성: `Question`(Title), `Answer`(Rich Text), `Category`(Select), `Order`(Number), `Active`(Checkbox)

### 빈 결과
- `Active` 체크박스가 체크되어 있는지 확인
- Database에 데이터가 있는지 확인

## 참고 링크

- [Notion API 공식 문서](https://developers.notion.com/)
- [Notion Database Query](https://developers.notion.com/reference/post-database-query)
- [Notion Create Page](https://developers.notion.com/reference/post-page)
