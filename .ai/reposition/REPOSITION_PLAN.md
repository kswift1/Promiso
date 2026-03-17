# Promiso 재포지셔닝 마스터 플랜 (확정)

> 이 문서는 모든 WS에서 참조하는 Single Source of Truth입니다.
> 각 WS별 상세 지시서: `WS1_INSTRUCTION.md` ~ `WS5_INSTRUCTION.md`

## 목표

"약속 관리 앱" → "약속 비서 앱" 재포지셔닝. 1주일 내 배포 (2026-03-24). base: `release/v1.2.0`.

## 확정 사항

- **Free 브리핑**: 일정 + 날씨 (교통 제외). 앱 열 때만 표시 (스케줄 Push는 Pro 전용)
- **Free 브리핑 트리거**: 일정 0개면 미생성 → 첫 일정 생기면 표시
- **Pro 업셀**: 교통/출발시간, 브리핑 스케줄 Push, 스타일 설정
- **v1.3.0 미룸**: 자연어 입력

## 의존성 + 머지 순서

```
WS1 (온보딩+Calendar+BottomSheet) ────── 독립          → 1번째 머지
WS2 (브리핑Free+Push톤+카피) ─────────── WS1 후 rebase → 2번째 머지
WS3 (시간 추천) ──────────────────────── 독립          → 3번째 머지
WS4 (애니메이션+LA+자동세팅) ─────────── WS1+WS2 후    → 4번째 머지
WS5 (독촉 자동화) ────────────────────── WS2 카피 기준 → 5번째 머지
```

## HomeFeature.swift 영역 분리

- WS1: calendar state, banner, sheet (상단~중단)
- WS2: 브리핑 generate 호출 조건 (briefing 영역)
- WS4: departure handler (하단)

## 타임라인

```
Day 1-2: 전체 동시 착수
Day 3:   WS2 코드 완료 (카피 기준 확정), WS4-A 완료
Day 4:   WS1 머지 → WS2 rebase+머지 → WS3 머지 → WS5 머지
Day 5:   WS4-B rebase+완료+머지
Day 6-7: 통합 빌드 + QA + 문서 + 배포
```

## 카피 톤 기준 (WS2가 확립, 다른 WS 참조)

- 주어는 "Promiso" (3인칭 비서)
- 이모지 자제 (제목에 최소한만)
- 존댓말 + 부드러운 톤
- Push: 정보 전달 → "~해볼까요?", "~해드릴게요" 패턴
