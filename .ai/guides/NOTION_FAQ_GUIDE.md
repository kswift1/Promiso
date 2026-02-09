# Notion FAQ 관리 가이드

## 개요

Promiso 앱의 FAQ는 Notion 데이터베이스에서 관리됩니다. 이를 통해 개발자가 아닌 팀원도 쉽게 FAQ를 추가/수정할 수 있습니다.

## Notion Database 구조

### Database ID
```
356188caae734b5ebd73203557a34930
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
DB_ID="356188caae734b5ebd73203557a34930"
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

### 403 Forbidden
- Integration이 Database에 연결되었는지 확인
- API Key가 올바른지 확인

### 404 Not Found
- Database ID가 올바른지 확인 (URL에서 추출)
- Notion URL: `https://notion.so/{database_id}?v=...`

### 빈 결과
- `Active` 체크박스가 체크되어 있는지 확인
- Database에 데이터가 있는지 확인

## 참고 링크

- [Notion API 공식 문서](https://developers.notion.com/)
- [Notion Database Query](https://developers.notion.com/reference/post-database-query)
- [Notion Create Page](https://developers.notion.com/reference/post-page)
