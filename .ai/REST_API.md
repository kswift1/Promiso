# REST API 엔드포인트

> Rust 백엔드 (`infra/rust-backend/`) API 목록

## 공통

- Base URL: Cloud Run 배포 후 결정
- 인증: `Authorization: Bearer <firebase_id_token>`
- 응답 포맷: `{"data": T}` (성공) / `{"error": {"code": "...", "message": "..."}}` (실패)
- snake_case (JSON)

## 인증 불필요

| Method | Path | 설명 |
|--------|------|------|
| GET | `/health` | 서버 + DB 상태 확인 |

## Users (인증 필요)

| Method | Path | 설명 | 비고 |
|--------|------|------|------|
| POST | `/api/v1/users` | 유저 생성 | body: {name?, nickname, provider} |
| GET | `/api/v1/users/me` | 본인 프로필 (private) | email, provider 포함 |
| PATCH | `/api/v1/users/me` | 닉네임 수정 | body: {nickname?} |
| POST | `/api/v1/users/me/profile-image` | 프로필 이미지 URL 저장 | body: {image_path} |
| GET | `/api/v1/users/nickname-check?q=` | 닉네임 중복 확인 | 본인 닉네임은 available=true |
| POST | `/api/v1/users/batch` | 여러 유저 조회 (public) | body: {user_ids: [...]} |
| GET | `/api/v1/users/{id}` | 타인 프로필 (public) | 공통 그룹 체크 (groups 마이그레이션 후) |

*마지막 업데이트: 2026-04-03*
