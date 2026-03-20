# Promiso 도메인 규칙 (Domain Rules)

> **이 문서와 `domain-rules/` 디렉토리는 Promiso의 비즈니스 규칙을 정의하는 단일 진실 소스입니다.**
>
> **🔒 수정 금지**: 이 문서와 `domain-rules/` 하위 파일은 사용자의 **명시적 허락 없이 절대 수정할 수 없습니다.**
> 규칙 추가/변경/삭제가 필요하면 반드시 사용자에게 먼저 확인받으세요.
> 코드 수정 시 규칙과 충돌이 발견되면 즉시 사용자에게 알리세요.

---

## 도메인별 핵심 요약

### [그룹 (Group)](domain-rules/group.md) — 32 rules

**핵심 제약**: 이름 2~12자, 설명 50자, 최대 인원 2~10명, 초대 코드 6자리 영숫자
**핵심 권한**: 수정/삭제 = 호스트만, 호스트 탈퇴 불가, 멤버만 조회
**핵심 동작**: 삭제 시 cascade (약속+멤버+Storage), 가입 시 기본 알림 ON

### [약속 (Promise)](domain-rules/promise.md) — 45 rules

**핵심 제약**: 제목 필수(최대 30자), 설명 500자, 시작 미래, 최소 참여 2명
**핵심 권한**: 수정/삭제 = 호스트 또는 그룹 호스트 & 시작 전만, LiveActivity 중 수정 불가
**핵심 동작**: 호스트 자동 수락, 확정 = accepted >= min, 응답 우선순위 4단계
**응답 상태**: `failed > needResponse > confirmed > responded`

### [사용자 (User)](domain-rules/user.md) — 16 rules

**핵심 제약**: 닉네임 2~12자, 공백 불가, 중복 불가, name/email 수정 불가
**핵심 권한**: 타인 조회 = 같은 그룹만, 그룹 호스트면 탈퇴 불가
**핵심 동작**: 탈퇴 cascade 10단계 (호스트 체크→약속삭제→그룹정리→투표정리→이미지→루트컬렉션정리→루트문서정리→서브컬렉션→유저문서→Auth)

### [알림 + 배지 (Notification & Badge)](domain-rules/notification.md) — 15 rules

**핵심**: 카테고리 9종, 트리거 5종, 그룹별 카테고리별 on/off, 기본 전체 ON
**배지**: 약속 생성 시 멤버 배지 ON (생성자 제외), 본인만 해제

### [LiveActivity](domain-rules/liveactivity.md) — 18 rules

**핵심 제약**: 프리셋 15/30/60분, 커스텀 최대 999분
**핵심 권한**: 시작 = 호스트만
**핵심 동작**: 확정 시 자동 예약, 30분 후 자동 종료, 모두 도착 시 지연 종료

### [위젯 (Widget)](domain-rules/widget.md) — 13 rules

**핵심 제약**: 토큰 30일, 데이터 최대 7개, 캐시 2시간
**핵심 보안**: 디바이스 바인딩, 버전 기반 무효화

### [쿠폰 (Coupon)](domain-rules/coupon.md) — 15 rules

**핵심 제약**: 1인 1쿠폰 (사용 이력 있으면 다른 쿠폰도 불가), 코드 8자리
**핵심 권한**: 생성 = admin/marketer, 사용 = 로그인 유저, 만료 = 관리자
**핵심 동작**: 사용 시 entitlementOverrides 생성 → reconcileEntitlement 자동 동기화
**UI**: Paywall에서만 쿠폰 입력 노출, ManageView 미노출

### [접근 제어 + 보안 (Security)](domain-rules/security.md) — 16 rules

**Firestore**: 본인 데이터 본인만, 그룹 데이터 멤버만, 알림 생성 Functions만
**보안 조치**: Field Path Injection 방지, 프로필 이미지 경로 검증, 트랜잭션 보호

---

## 규칙 통계

| 도메인 | 규칙 수 | 상세 문서 |
|--------|:------:|----------|
| 그룹 | 32 | [domain-rules/group.md](domain-rules/group.md) |
| 약속 | 45 | [domain-rules/promise.md](domain-rules/promise.md) |
| 사용자 | 16 | [domain-rules/user.md](domain-rules/user.md) |
| 알림+배지 | 15 | [domain-rules/notification.md](domain-rules/notification.md) |
| LiveActivity | 18 | [domain-rules/liveactivity.md](domain-rules/liveactivity.md) |
| 위젯 | 13 | [domain-rules/widget.md](domain-rules/widget.md) |
| 쿠폰 | 15 | [domain-rules/coupon.md](domain-rules/coupon.md) |
| 보안 | 16 | [domain-rules/security.md](domain-rules/security.md) |
| **합계** | **170** | |

---

## 관련 문서

- [DOMAIN_RULES_BACKLOG.md](DOMAIN_RULES_BACKLOG.md) — 충돌/누락/예정 변경사항 추적
- [TEST_POLICY.md](TEST_POLICY.md) — 테스트 설계 기준

---

*마지막 업데이트: 2026-02-12*
