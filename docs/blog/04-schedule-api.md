# Firebase에서 Rust로 -- 일정 API, 투표 상태 머신과 세 개의 컬렉션

*iOS 앱 서버 마이그레이션기 #4 -- 그룹일정 + 개인일정 + 반복일정을 하나의 테이블로*

---

Firestore에서 일정 관련 데이터는 세 곳에 흩어져 있다.

`promises/{id}` -- 그룹일정. 투표(votes Map), 확정 여부, 장소, 이미지.
`users/{uid}/personalEvents/{id}` -- 개인일정. 그룹 없이 나만 보는 일정.
`users/{uid}/scheduleSlots/{YYYY-MM-DD}` -- 충돌 감지용 비정규화. 날짜별로 일정 조각을 복사해둔다.

이 세 가지가 캘린더 화면에서 합쳐져야 한다. 그룹일정과 개인일정을 시간순으로 섞어서 보여주고, 새 일정을 만들 때는 기존 일정과 겹치는지 확인해야 한다. Firestore에서 이걸 하려면 컬렉션 세 개를 각각 쿼리하고, 클라이언트에서 합치고, 정렬한다.

충돌 감지가 특히 고통스러웠다. Firestore는 "이 유저의 모든 일정을 시간 범위로 조회"하는 쿼리를 단일 호출로 지원하지 않는다. 그래서 `scheduleSlots`라는 비정규화 컬렉션을 만들었다. 일정이 생기면 트리거가 해당 날짜의 슬롯 문서에 복사본을 추가한다. 일정이 바뀌면 옛날 슬롯을 지우고 새 슬롯을 넣는다. 삭제되면 슬롯도 지운다. 그룹일정에 3개, 개인일정에 3개, 조회에 1개. 총 7개의 Cloud Functions 트리거가 이 비정규화를 유지한다.

이 트리거들은 실수하기 쉽다. 일정 시간이 바뀌면 옛날 날짜의 슬롯을 지우고 새 날짜에 넣어야 하는데, "이전 startAt"과 "새 startAt"을 둘 다 들고 다녀야 한다. 투표 상태가 바뀌면 수락한 멤버의 슬롯만 추가하거나 제거해야 한다. 반복일정은 규칙 기반이라 슬롯이 없고 조회 시점에 확장한다. 결과적으로 충돌 감지 하나를 위해 데이터 경로가 셋으로 갈라진다.

PostgreSQL로 옮기면서 질문은 하나였다. 이 복잡도 중 얼마가 비즈니스 규칙이고 얼마가 Firestore 제약인가.

---

## 세 컬렉션을 하나의 테이블로

결론부터. `promises` + `personalEvents`를 `schedules` 하나로 합쳤다. `scheduleSlots`는 제거했다.

```sql
CREATE TABLE schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_type schedule_type NOT NULL,  -- 'group' | 'personal'
  user_id TEXT NOT NULL REFERENCES users(id),

  title TEXT NOT NULL,
  emoji TEXT,
  start_at TIMESTAMPTZ NOT NULL,
  end_at TIMESTAMPTZ,
  -- ... 공통 필드 ...

  -- 그룹일정 전용 (personal이면 NULL)
  group_id UUID REFERENCES groups(id),
  minimum_participants SMALLINT,
  is_confirmed BOOLEAN,
  vote_deadline TIMESTAMPTZ,

  -- 개인일정 전용 (group이면 NULL)
  reminder_minutes_before SMALLINT,

  CONSTRAINT chk_schedule_type_fields CHECK (
    (schedule_type = 'group'
      AND group_id IS NOT NULL
      AND minimum_participants IS NOT NULL)
    OR
    (schedule_type = 'personal'
      AND group_id IS NULL
      AND minimum_participants IS NULL)
  )
);
```

`schedule_type` enum으로 구분하고, CHECK 제약으로 타입별 필드를 강제한다. 그룹일정인데 `group_id`가 없으면 INSERT 자체가 실패한다. 개인일정인데 `minimum_participants`가 있어도 실패한다. DB가 규칙을 지킨다.

왜 합쳤을까? Firestore에서 분리된 이유를 먼저 보면 -- `promises`는 최상위 컬렉션이고 `personalEvents`는 유저 서브컬렉션이다. 이렇게 나눈 건 보안 규칙 때문이다. Firestore 보안 규칙은 경로 기반이다. `users/{uid}/personalEvents/{id}`로 두면 "본인 문서만 읽기"를 경로 패턴 하나로 끝낼 수 있다. `promises`는 그룹 멤버 전체가 읽어야 하니까 별도 컬렉션에 두고 멤버십 체크를 따로 건다.

PostgreSQL에서는 보안이 경로가 아니라 API 레이어에서 동작한다. 서비스 함수에서 "개인일정이면 `user_id` 일치 확인, 그룹일정이면 그룹 멤버십 확인"을 코드로 처리한다. 분리의 이유가 사라졌고, 합침의 이유가 생겼다. 캘린더에서 한 쿼리로 두 타입을 섞어서 조회할 수 있다.

반복일정(`recurringEvents`)은 별도 테이블 `recurring_schedules`로 유지했다. 이건 Firestore를 따라간 게 아니라, 본질적으로 다른 엔티티이기 때문이다. `schedules`는 "4월 7일 14시에 영화"처럼 구체적인 시점을 저장한다. `recurring_schedules`는 "매주 월수금 19시에 헬스장"이라는 규칙을 저장한다. 필드 구조가 완전히 다르다 -- 하나는 `start_at: TIMESTAMPTZ`이고 다른 하나는 `start_time_hour: SMALLINT` + `start_time_minute: SMALLINT`이다.

---

## scheduleSlots, 사라지다

7개 트리거를 유지하던 `scheduleSlots`는 SQL 한 줄로 대체된다.

```sql
-- 이 유저의 모든 일정을 시간 범위로 조회 (충돌 감지)
SELECT s.id, s.title, s.start_at, s.end_at
FROM schedules s
JOIN schedule_votes sv ON sv.schedule_id = s.id
WHERE sv.user_id = $1 AND sv.status = 'accepted'
  AND s.start_at < $3 AND (s.end_at > $2 OR s.end_at IS NULL)
UNION ALL
SELECT s.id, s.title, s.start_at, s.end_at
FROM schedules s
WHERE s.schedule_type = 'personal' AND s.user_id = $1
  AND s.start_at < $3 AND (s.end_at > $2 OR s.end_at IS NULL);
```

그룹일정은 `schedule_votes`와 JOIN해서 내가 수락한 것만 가져오고, 개인일정은 `user_id`로 직접 필터한다. 인덱스 두 개면 충분하다.

```sql
CREATE INDEX idx_schedule_votes_user ON schedule_votes (user_id, status);
CREATE INDEX idx_schedules_personal_start ON schedules (user_id, start_at)
  WHERE schedule_type = 'personal';
```

Firestore에서 비정규화가 필요했던 이유는 "여러 컬렉션을 걸치는 범위 쿼리"가 불가능해서였다. SQL에서는 JOIN + WHERE로 끝난다. 7개 트리거, 슬롯 생성/삭제/갱신 로직, 날짜 키 계산 코드가 전부 사라졌다.

---

## 투표 상태 머신

그룹일정의 핵심은 투표다. 멤버가 일정을 수락하거나 거절하고, 최소 인원이 모이면 확정된다.

Firestore에서 투표는 `votes` Map이다.

```json
{
  "votes": {
    "accepted": ["user_A", "user_B"],
    "declined": ["user_C"],
    "until": "2026-04-10T19:00:00+09:00"
  },
  "minimumParticipants": 2,
  "isConfirmed": true
}
```

`accepted`와 `declined`는 userId 배열이다. pending은 저장하지 않고 "그룹 멤버 - accepted - declined"로 계산한다. `isConfirmed`는 `accepted.length >= minimumParticipants`의 비정규화 필드다.

이 구조 자체는 Firestore에 맞춤 설계된 것이다. `arrayUnion`/`arrayRemove`로 배열을 Set처럼 쓸 수 있고, 단일 문서 리스너 하나로 모든 투표 변화를 감지할 수 있다.

PostgreSQL에서는 정규화된 테이블로 바꿨다.

```sql
CREATE TABLE schedule_votes (
  schedule_id UUID REFERENCES schedules(id) ON DELETE CASCADE,
  user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
  status vote_status NOT NULL,  -- 'accepted' | 'declined'
  responded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (schedule_id, user_id)
);
```

pending은 여전히 저장하지 않는다. `group_members`에 있는데 `schedule_votes`에 없으면 pending이다. 이 설계는 Firebase와 같은 원칙이다.

투표 응답 로직은 트랜잭션 안에서 동작한다.

```rust
let mut tx = pool.begin().await?;

match status {
    "accepted" | "declined" => {
        // UPSERT -- 이미 투표했으면 상태만 바꾼다
        sqlx::query(
            "INSERT INTO schedule_votes (schedule_id, user_id, status)
             VALUES ($1, $2, $3::vote_status)
             ON CONFLICT (schedule_id, user_id)
             DO UPDATE SET status = $3::vote_status, responded_at = NOW()"
        )
        .bind(schedule_id).bind(user_id).bind(status)
        .execute(&mut *tx).await?;
    }
    "pending" => {
        // 투표 취소 = row 자체를 삭제
        sqlx::query(
            "DELETE FROM schedule_votes
             WHERE schedule_id = $1 AND user_id = $2"
        )
        .bind(schedule_id).bind(user_id)
        .execute(&mut *tx).await?;
    }
}

// is_confirmed 재계산 -- 같은 트랜잭션에서
let accepted_count: i64 = sqlx::query_scalar(
    "SELECT COUNT(*) FROM schedule_votes
     WHERE schedule_id = $1 AND status = 'accepted'"
)
.bind(schedule_id)
.fetch_one(&mut *tx).await?;

let new_confirmed = accepted_count >= minimum_participants as i64;
sqlx::query("UPDATE schedules SET is_confirmed = $1 WHERE id = $2")
    .bind(new_confirmed).bind(schedule_id)
    .execute(&mut *tx).await?;

tx.commit().await?;
```

Firestore에서도 `runTransaction` 안에서 같은 일을 했다. 차이는 `arrayUnion`/`arrayRemove` 대신 `INSERT ON CONFLICT`와 `DELETE`를 쓴다는 것, 그리고 `is_confirmed` 재계산이 배열 길이가 아니라 `COUNT(*)` 쿼리라는 것이다. 비즈니스 규칙은 같고 표현 방식만 다르다.

`is_confirmed`를 별도 컬럼으로 유지한 이유는 쿼리 때문이다. 캘린더 동기화에서 "확정된 미래 일정"만 가져와야 하는데, `WHERE is_confirmed = TRUE AND start_at >= NOW()` 한 줄이면 된다. 매번 votes를 세서 판단하는 것보다 인덱스가 명확하다.

---

## 반복일정의 frequency별 상호배타

반복일정 스키마에서 재미있었던 부분은 CHECK 제약이다.

```sql
CONSTRAINT chk_recurrence_fields CHECK (
  (frequency = 'daily'
    AND days_of_week IS NULL
    AND day_of_month IS NULL)
  OR
  (frequency = 'weekly'
    AND days_of_week IS NOT NULL
    AND array_length(days_of_week, 1) > 0
    AND day_of_month IS NULL)
  OR
  (frequency = 'monthly'
    AND days_of_week IS NULL
    AND day_of_month IS NOT NULL
    AND day_of_month BETWEEN 1 AND 31)
)
```

daily인데 `days_of_week`가 있으면? INSERT 실패. weekly인데 `days_of_week`가 빈 배열이면? INSERT 실패. monthly인데 `day_of_month`가 없으면? INSERT 실패. 서비스 코드가 검증을 빼먹어도 DB가 잡아준다.

Swift에서 이런 상호배타를 표현하려면 associated value가 있는 enum을 쓴다.

```swift
enum Recurrence {
    case daily
    case weekly(daysOfWeek: [Int])
    case monthly(dayOfMonth: Int)
}
```

타입 시스템이 "weekly이면 반드시 daysOfWeek가 있다"를 컴파일 타임에 보장한다. SQL의 CHECK 제약은 같은 보장을 런타임에, DB 레벨에서 제공한다. 계층이 다를 뿐 목적은 같다.

---

## 코드: Before/After

### 일정 생성

Firebase에서는 그룹일정과 개인일정이 완전히 다른 경로를 탄다.

```typescript
// Firebase: 그룹일정 -- Cloud Function
export const createPromise = onCall(async (request) => {
  const promiseRef = promisesCollection.doc();
  await promiseRef.set({
    title, groupId, hostId: userId,
    votes: { accepted: [userId], declined: [], until: startAt },
    isConfirmed: initialAccepted.length >= minimumParticipants,
    // ... 20줄 더 ...
  });
  return { promiseId: promiseRef.id };
});

// Firebase: 개인일정 -- 클라이언트가 Firestore 직접 쓰기
db.collection("users").document(userId)
  .collection("personalEvents").addDocument(data: [...])
```

Rust에서는 `schedule_type`으로 분기하는 하나의 함수다.

```rust
pub async fn create_schedule(
    pool: &PgPool, user_id: &str, req: CreateScheduleRequest
) -> Result<CreateScheduleResponse, AppError> {
    match req.schedule_type {
        ScheduleType::Group => {
            // 그룹 멤버십 확인 + INSERT + 호스트 자동 투표
            let mut tx = pool.begin().await?;
            let schedule = sqlx::query_as::<_, Schedule>(
                "INSERT INTO schedules (...) VALUES (...) RETURNING *"
            ).fetch_one(&mut *tx).await?;

            // 호스트 자동 accepted
            sqlx::query("INSERT INTO schedule_votes ...")
                .execute(&mut *tx).await?;
            tx.commit().await?;
        }
        ScheduleType::Personal => {
            // user_id만 확인 + INSERT
            sqlx::query_as::<_, Schedule>(
                "INSERT INTO schedules (...) VALUES (...) RETURNING *"
            ).fetch_one(pool).await?;
        }
    }
}
```

### 캘린더 조회

Firebase에서는 세 곳을 따로 쿼리한다.

```swift
// iOS: 그룹일정 -- groupId별로 쿼리 (최대 10개씩 청크)
for chunk in groupIds.chunked(into: 10) {
    let snapshot = try await db.collection("promises")
        .whereField("groupId", in: chunk)
        .whereField("startAt", isGreaterThan: startDate)
        .getDocuments()
}

// iOS: 개인일정
let personal = try await db.collection("users").document(uid)
    .collection("personalEvents")
    .whereField("startAt", isGreaterThan: startDate)
    .getDocuments()

// 클라이언트에서 합치기 + 정렬
let all = (groupSchedules + personalSchedules).sorted(by: \.startAt)
```

Rust에서는 서버가 합쳐서 준다.

```rust
// 그룹 + 개인 한 번에
let schedules = sqlx::query_as::<_, Schedule>(
    "SELECT * FROM schedules
     WHERE (schedule_type = 'group' AND group_id = ANY($1))
        OR (schedule_type = 'personal' AND user_id = $2)
     AND start_at BETWEEN $3 AND $4
     ORDER BY start_at"
)
.bind(&group_ids).bind(user_id)
.bind(start).bind(end)
.fetch_all(pool).await?;
```

Firestore의 `in` 연산자 10개 제한으로 청크를 나누던 코드가 PostgreSQL의 `= ANY($1)` 한 줄로 줄었다. 클라이언트에서 합치고 정렬하던 로직이 서버 `ORDER BY`로 이동했다.

---

## 사라진 것들

이번 마이그레이션에서 제거된 것들.

- `scheduleSlots` 컬렉션 전체 + 7개 Firestore 트리거
- `promises`와 `personalEvents` 분리 -- 단일 `schedules` 테이블로 통합
- Firestore `in` 연산자 10개 제한 대응 청크 코드
- 클라이언트 측 일정 합치기/정렬 로직
- `arrayUnion`/`arrayRemove` 기반 투표 로직 -- SQL UPSERT/DELETE로 대체
- `votes` 서브컬렉션 (LiveActivity 브로드캐스트용) -- 향후 별도 처리
- `badgesCleared` 플래그 -- 알림 마이그레이션(#5)에서 재설계

새로 생긴 것도 있다. 제목 30자 제한, 설명 500자 제한, 종료 시간 > 시작 시간 검증, 시작 시간 미래 검증. Firebase 때 빠져 있던 서버 측 검증을 Rust에서 추가했다. 이건 마이그레이션의 부수 효과다. 코드를 다시 쓰면서 누락된 검증이 보인다.

---

## 마무리

세 컬렉션을 하나의 테이블로 합치고, 7개 트리거를 SQL 한 줄로 대체하고, 투표 상태 머신을 트랜잭션으로 감쌌다. 변경량은 그룹 때보다 많았지만 원칙은 같다. Firestore 제약에서 나온 복잡도를 걷어내고, 비즈니스 규칙만 남긴다.

`scheduleSlots`가 대표적이다. Firestore에서는 "여러 컬렉션을 걸치는 범위 쿼리"가 안 되니까 날짜별 비정규화를 만들고, 7개 트리거로 유지했다. PostgreSQL에서는 JOIN + WHERE로 같은 결과를 얻는다. 트리거 7개가 하던 일을 인덱스 2개가 대신한다.

*다음 글: #5 알림과 푸시 -- FCM 직접 발송 + 배지 + 그룹별 설정*

*Promiso -- [App Store](https://apps.apple.com/kr/app/id6757733720) · [GitHub](https://github.com/kswift1/Promiso)*
