# Firebase에서 Rust로 — 그룹 API, Firestore에서 PostgreSQL로

*iOS 앱 서버 마이그레이션기 #3 — 비정규화에서 정규화로, 스키마 재설계의 모든 것*

---

그룹을 만들 때 데이터를 두 곳에 써야 한다는 걸 처음 알았을 때, 뭔가 이상하다고 느꼈다.

Firestore에서 그룹 데이터는 두 곳에 나뉘어 있다. `groups/{groupId}` 문서에 그룹 기본 정보가 있고:

```json
{
  "name": "주말 등산 모임",
  "memberIds": ["user_A", "user_B", "user_C"],
  "createdBy": "user_A",
  "maxMembers": 10,
  "inviteCode": "AB12CD",
  "imageUrl": "https://storage.googleapis.com/..."
}
```

`users/{uid}.groups` Map에 그룹 이름과 이미지가 복사되고, 역할이나 알림 설정 같은 멤버별 데이터도 함께 들어간다:

```json
{
  "groups": {
    "group_123": {
      "groupName": "주말 등산 모임",
      "role": "admin",
      "imageUrl": "https://storage.googleapis.com/...",
      "hasNewActivity": false,
      "notifications": { "enabled": true, "promise": { ... }, "group": { ... } }
    }
  }
}
```

왜 이렇게 했을까? Firestore는 SQL처럼 테이블을 엮는 JOIN이 안 된다. "내가 속한 그룹 목록"을 보여주려면 모든 그룹 문서를 뒤지거나, 유저 문서에 미리 복사해두거나. Firestore는 문서 읽기당 과금이니까, 유저 문서 하나만 읽으면 그룹 목록이 통째로 나오는 후자가 빠르고 싸다. 읽기 성능만 보면 합리적인 구조였다.

대신 쓰기에서 비용이 생긴다. 그룹 이름과 이미지 URL이 양쪽에 있으니 바뀔 때마다 동기화해야 한다. 이미지가 바뀌면 `onGroupImageUpdated` 트리거가 모든 멤버의 복사본을 갱신한다. 멤버가 가입하면 `groups.memberIds` 배열과 `users.groups` Map을 둘 다 업데이트해야 한다. 실제로 이 동기화가 어긋난 적이 있다. 그룹 이미지를 바꿨는데 목록에서는 옛날 이미지가 보이는 버그. 트리거가 지연된 거였다. 고치는 건 어렵지 않았지만, 같은 구조의 문제가 이름, 멤버십에서도 반복될 수 있다는 게 진짜 문제였다.

PostgreSQL로 옮기면서 이 구조를 그대로 가져갈 이유가 없었다. PostgreSQL에는 JOIN이 있다. 조인 테이블 하나면 복사 없이 같은 결과를 얻을 수 있고, 동기화 트리거도 필요 없다. Firestore의 비정규화는 Firestore라는 제약에서 나온 우발적 복잡도였지, 그룹 도메인의 본질이 아니다. 1:1로 복사하는 대신 PostgreSQL에 맞게 다시 설계하기로 했다.

---

## PostgreSQL 그룹 스키마

재설계한 스키마는 두 테이블이다. `groups`와 `group_members`.

```sql
CREATE TABLE groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  image_url TEXT,
  max_members SMALLINT NOT NULL DEFAULT 10,
  invite_code CHAR(6) NOT NULL,
  last_activity_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT chk_group_name_len
    CHECK (char_length(name) BETWEEN 2 AND 12),
  CONSTRAINT chk_group_max_members
    CHECK (max_members BETWEEN 2 AND 10)
);

CREATE TABLE group_members (
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
  user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
  role group_member_role NOT NULL DEFAULT 'member',
  group_color TEXT NOT NULL DEFAULT '#AF52DE',
  notifications_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  -- ... 알림 설정 필드들 ...
  calendar_sync BOOLEAN NOT NULL DEFAULT TRUE,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (group_id, user_id)
);
```

변경이 많지만 관통하는 원칙은 하나다. 데이터를 한 곳에만 두고, 필요할 때 JOIN으로 조합한다.

가장 큰 변화는 `createdBy` 컬럼을 없앤 것이다. Firestore에서는 그룹 문서에 `createdBy` 필드를 두고 호스트를 판별했다. 문제는 호스트 양도(transfer)다. 양도하면 "생성자"와 "현재 호스트"가 달라진다. 누가 진짜 호스트인지 코드마다 판단이 갈린다. PostgreSQL에서는 `group_members` 테이블에 `role = 'admin'`인 row가 곧 호스트다. 양도할 때 role만 바꾸면 끝이고, "그룹당 admin은 정확히 1명"이라는 규칙을 DB가 강제한다.

```sql
CREATE UNIQUE INDEX uq_group_members_single_admin
  ON group_members (group_id)
  WHERE role = 'admin';
```

알림 설정도 구조가 바뀌었다. 유저가 그룹별로 어떤 푸시 알림을 받을지 토글하는 기능인데 — 일정 초대, 리마인더, 확정, 취소 등 8개 항목을 개별적으로 켜고 끌 수 있다. Firestore에서는 이걸 중첩 Map(`notifications.promise.invitation`)으로 저장했고, 레거시와 신형 포맷이 공존해서 파싱이 복잡했다. PostgreSQL에서는 `notifications_enabled`, `schedule_invitation`, `group_update` 같은 개별 boolean 컬럼으로 펼쳤다. 토글 수가 고정되어 있으니 NOT NULL + DEFAULT로 빈 상태 자체를 없앨 수 있다.

그룹 목록에서 "안 본 새 일정이 있는지" 표시하는 배지도 방식이 달라졌다. Firestore에서는 새 일정이 생기면 트리거가 멤버 전원의 `hasNewActivity`를 `true`로 바꿨다. 유저가 그룹을 열면 `false`로. boolean 하나를 N명의 유저 문서에 쓰는 구조다. PostgreSQL에서는 저장하지 않고 계산한다. `groups.last_activity_at > group_members.last_read_at`이면 새 활동이 있는 것이다. 플래그를 수동 관리하는 코드가 통째로 사라졌다.

멤버 관리는 `group_members` 조인 테이블이 전부 담당한다. `memberIds` 배열도, `users.groups` Map도 없다. 그룹을 삭제하면 `ON DELETE CASCADE`가 멤버를 자동 정리한다. Firestore에서 멤버 한 명씩 Map 키를 지우던 코드가 필요 없다.

| 항목 | Firestore | PostgreSQL |
|------|-----------|------------|
| 멤버 관리 | `memberIds` 배열 + `users.groups` Map | `group_members` 조인 테이블 |
| 호스트 판별 | `createdBy` 필드 | `role = 'admin'` |
| 알림 설정 | 중첩 Map (레거시 + 신형) | 명시 boolean 컬럼 |
| 새 활동 표시 | `hasNewActivity` 플래그 | 타임스탬프 비교 |
| 이미지 동기화 | 트리거로 복사본 갱신 | JOIN (트리거 없음) |
| 그룹 삭제 | 멤버별 수동 정리 | `ON DELETE CASCADE` |

---

## 코드: Before/After

차이가 가장 극적으로 드러나는 두 가지를 비교한다.

### 그룹 생성

Firebase에서는 그룹 문서와 유저 문서를 따로 써야 한다. 두 번의 쓰기, 두 곳의 데이터.

```typescript
// Firebase: 그룹 생성 — 두 곳에 쓴다
await groupRef.set({
  name: data.name,
  memberIds: [creatorId],
  createdBy: creatorId,
  inviteCode, maxMembers: data.maxMembers,
});

await usersCollection.doc(creatorId).set({
  groups: { [groupId]: { groupName: data.name, role: "admin", ... } }
}, { merge: true });
```

Rust에서는 트랜잭션 하나에 `groups` INSERT와 `group_members` INSERT를 묶는다. 데이터는 한 곳에만 존재한다.

```rust
// pool.begin() — Swift의 Firestore runTransaction과 비슷하지만
// 테이블을 가리지 않는다. 실패 시 자동 롤백.
let mut tx = pool.begin().await?;

// INSERT ... RETURNING * — Swift에는 없는 패턴.
// INSERT하면서 DB가 생성한 UUID, created_at 등을 바로 돌려받는다.
let group = sqlx::query_as::<_, Group>(
    "INSERT INTO groups (name, description, max_members, invite_code)
     VALUES ($1, $2, $3, $4) RETURNING *"
)
.bind(&name).bind(&description)
.bind(max_members).bind(&invite_code)
.fetch_one(&mut *tx).await?; // ? — Swift의 try에 해당

// createdBy 필드 대신 role = 'admin'이 호스트를 표현한다
sqlx::query(
    "INSERT INTO group_members (group_id, user_id, role)
     VALUES ($1, $2, 'admin')"
)
.bind(group.id).bind(creator_uid)
.execute(&mut *tx).await?;

tx.commit().await?;
```

### 내 그룹 목록 조회

Firebase에서는 유저 문서의 `groups` Map을 읽는다. 이게 비정규화의 보상이다 — 1번의 읽기로 모든 그룹 정보를 얻는다. 하지만 거기에 저장된 건 "복사본"이다. 그룹 이름이나 이미지가 바뀌었는데 트리거가 실패했으면 오래된 정보가 보인다.

Rust에서는 JOIN 단일 쿼리다.

```rust
// JOIN — Firestore에는 없는 것. 두 테이블을 한 쿼리로 엮는다.
// Swift로 치면 fetchGroups + fetchGroupMembers를 한 번에 하는 셈.
let rows = sqlx::query_as::<_, _>(
    "SELECT g.id, g.name, g.image_url, g.max_members,
            gm.role::TEXT, gm.group_color,
            g.last_activity_at, gm.last_read_at,
            -- 서브쿼리로 멤버 수도 같이 가져온다. 별도 COUNT 호출 불필요.
            (SELECT COUNT(*) FROM group_members
             WHERE group_id = g.id) AS member_count
     FROM group_members gm
     JOIN groups g ON gm.group_id = g.id
     WHERE gm.user_id = $1
     ORDER BY gm.joined_at DESC"
)
.bind(user_uid)
.fetch_all(pool).await?; // fetch_all — Swift의 [Model] 반환과 같다
```

복사본이 아니라 원본을 직접 읽는다. 동기화 지연이 원리적으로 불가능하다. 쿼리 하나에 그룹 정보, 멤버십 정보, 멤버 수까지 전부 나온다. Firestore에서 `fetchGroupMembers`를 그룹 수만큼 호출하던 N+1 문제도 사라진다.

---

## 구현하면서 발견한 것들

1편에서 정한 대로 비즈니스 규칙을 추출하고 Rust 테스트를 먼저 작성했다. 65개. 스키마 설계부터 구현까지 Claude Code와 함께 작업했다. 테스트를 통과시키는 건 어렵지 않았다. 문제는 그 다음에 나왔다. Codex에게 코드 리뷰를 돌렸더니 놓친 것들이 보이기 시작했다.

그룹을 만들 때 초대 코드를 생성하는데, 이 코드에 유니크 제약이 있다. 코드를 만들고 그룹을 INSERT하는 사이에 다른 요청이 같은 코드로 INSERT하면 충돌이 난다. 처음에는 이 두 단계가 같은 트랜잭션에 묶여 있지도 않았다. 그룹 INSERT는 성공했는데 멤버 INSERT가 실패하면 admin 없는 고아 그룹이 DB에 남는다.

비슷한 문제가 그룹 가입에도 있었다. 정원이 9/10인 그룹에 두 명이 동시에 가입 요청을 보내면, 둘 다 "아직 자리 있네" 판단을 통과해서 11/10이 되는 race condition. 그리고 그룹 목록을 가져올 때 멤버 수를 그룹별로 따로 세는 N+1 쿼리도 처음 구현에 있었다.

Firebase에서는 이런 문제를 어떻게 다뤘나? 솔직히 제대로 다루지 못했다. Firestore 트랜잭션은 문서 단위라 여러 컬렉션에 걸친 원자적 업데이트가 까다롭다. batch 500건 제한이나 트리거 타이밍 문제가 얽히면서 결국 "대부분의 경우 괜찮다"에 의존했다.

PostgreSQL에서는 트랜잭션이 테이블을 가리지 않는다. `groups`와 `group_members`를 한 트랜잭션에 묶으면 전부 성공하거나 전부 롤백된다. 그룹 가입도 트랜잭션 안에서 정원을 확인하고 INSERT하면 race condition이 사라진다.

---

## 사라진 것들

이번 마이그레이션에서 제거된 것들을 정리하면 이렇다.

- `onGroupImageUpdated` 트리거 — JOIN으로 대체
- `users.groups` Map 전체 — `group_members` 테이블로 통합
- `groups.memberIds` 배열 — 같은 테이블로 대체
- `createdBy` 필드 — `role = 'admin'`으로 통합
- `hasNewActivity` boolean 수동 관리 — 타임스탬프 비교로 계산
- 알림 설정 레거시/신형 이중 포맷 — 단일 boolean 컬럼
- Firestore batch 500건 제한 대응 코드 — PostgreSQL에서는 불필요
- 클라이언트 측 groupId 생성 + 중복 체크 — 서버 UUID 생성
- `maxMembers` 플랜별 분기 (Free 10명, Pro 30명) — 일률 10명

동기화 트리거가 사라지고, 수동 플래그 관리가 사라지고, 레거시 호환 코드가 사라졌다. 남은 건 비즈니스 규칙뿐이다.

---

## 마무리

문서 DB에서 관계형 DB로 옮기는 건 스키마를 복사하는 작업이 아니다. 기존 구조에서 "제약 때문에 어쩔 수 없이 넣은 것"과 "비즈니스 규칙 때문에 필요한 것"을 분리하는 작업이다.

Firestore의 비정규화는 Firestore 안에서는 합리적이었다. 그걸 PostgreSQL로 들고 가면 합리성의 근거가 사라진다. JOIN이 되니까 복사할 필요가 없고, 트랜잭션이 테이블을 가리지 않으니까 동기화 트리거가 필요 없다.

26건의 수정 사항 중 절반은 이 "구조적 제약의 산물 제거"였다. 나머지 절반이 버그 수정, 보안 강화, 레거시 정리. 결국 마이그레이션은 복사가 아니라 재해석이다. 어떤 규칙이 본질적이고 어떤 규칙이 우발적인지, DB를 바꾸면 그게 보인다.

*다음 글: #4 일정 API — 투표, 확정, 반복 일정까지*

*Promiso — [App Store](https://apps.apple.com/kr/app/id6757733720) · [GitHub](https://github.com/kswift1/Promiso)*
