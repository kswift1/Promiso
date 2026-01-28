# 지식 베이스 인덱스

> 이 디렉토리는 `knowledge-updater` 에이전트가 검색한 정보를 캐싱합니다.
> 중복 검색을 방지하고, 검증된 정보를 재사용합니다.

## 캐시 파일 목록

| 파일 | 기술 | TTL | 최종 업데이트 | 상태 |
|------|------|-----|--------------|------|
| [tca.md](./tca.md) | TCA (Composable Architecture) | 2주 | - | 초기화 필요 |
| [swiftui.md](./swiftui.md) | SwiftUI / iOS | 3개월 | - | 초기화 필요 |
| [firebase.md](./firebase.md) | Firebase iOS SDK | 1개월 | - | 초기화 필요 |
| [tuist.md](./tuist.md) | Tuist | 1개월 | - | 초기화 필요 |

## 사용 방법

### 자동 (권장)
`knowledge-updater` 에이전트가 자동으로 캐시를 확인하고 업데이트합니다.

### 수동 갱신
특정 기술의 정보를 강제로 갱신하려면:
```
"TCA 최신 정보 다시 검색해줘" (캐시 무시)
```

## 신선도 정책

| 기술 | TTL | 이유 |
|------|-----|------|
| TCA | 2주 | Point-Free 월 1-2회 릴리즈 |
| Firebase | 1개월 | Google 월간 릴리즈 |
| SwiftUI/iOS | 3개월 | Apple WWDC 연간 업데이트 |
| Tuist | 1개월 | 활발한 오픈소스 개발 |

## 캐시 파일 형식

```yaml
---
updated: YYYY-MM-DD      # 마지막 업데이트
expires: YYYY-MM-DD      # 만료일
version: X.X.X           # 확인된 최신 버전
source: URL              # 정보 출처
---
```

## 주의사항

- 캐시 파일을 직접 수정하지 마세요
- `knowledge-updater` 에이전트가 자동으로 관리합니다
- 잘못된 정보 발견 시 해당 파일 삭제 후 재검색 요청
