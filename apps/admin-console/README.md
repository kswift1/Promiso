# Admin Console

Promiso 운영 콘솔용 웹 앱입니다.

## 목표

- ProPlan 운영 지원
- 사용자 조회
- entitlement override 관리
- 운영 공지 푸시 발송
- release control / audit log 확인

## 개발

```bash
npm install
npm run dev
```

## 빌드

```bash
npm run build
```

## 구조

```text
apps/admin-console/
  src/
    layout/
    pages/
```

## 원칙

- 브라우저에서 직접 관리자 쓰기 로직을 수행하지 않습니다.
- 모든 위험한 작업은 admin-only Functions를 통해 실행합니다.
- 이 앱은 운영 UI 역할만 합니다.

