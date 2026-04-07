# Strict Coder

A harness that controls AI autonomy levels during code writing sessions.
Prevents completion bias — the tendency of LLMs to skip process steps for efficiency.

AI 코드 작성 시 자율성 수준을 제어하는 하네스.
LLM의 완료 편향(프로세스를 건너뛰고 효율을 택하는 경향)을 억제한다.

## Quick Start

```bash
# Install (sets up git hooks, Claude Code hooks, .gitignore)
./.ai/strict-coder/install.sh

# TDD workflow
.ai/strict-coder/scripts/tdd-red.sh --test {test_file}    # Run tests, expect failures
.ai/strict-coder/scripts/tdd-green.sh                      # Run tests, expect passes
.ai/strict-coder/scripts/tdd-status.sh                     # Check current phase
.ai/strict-coder/scripts/tdd-reset.sh                      # Reset for new cycle
```

## Structure / 구조

```
strict-coder/
├── README.md              ← You are here
├── install.sh             — One-command setup / 원커맨드 설치
├── modes/                 — AI autonomy levels / AI 자율성 수준
│   ├── suggest.md         — Default: ask before every decision / 판단마다 확인
│   └── drive.md           — Autonomous: ask only for big changes / 큰 전환만 확인
├── profiles/              — Learning profiles / 학습 프로필
│   ├── README.md          — Profile settings & custom creation / 설정값 정의
│   ├── learner.md         — Beginner: always explain with familiar language / 항상 비교 설명
│   └── practitioner.md    — Intermediate: explain on request only / 요청 시만 설명
├── scripts/               — Layer 2: TDD state machine / TDD 상태 전이
│   ├── tdd-red.sh         — Run tests → expect FAILED → record state
│   ├── tdd-green.sh       — Verify red state → run tests → expect ok → record state
│   ├── tdd-status.sh      — Print current .tdd-state
│   └── tdd-reset.sh       — Clear state for new cycle
└── hooks/                 — Layer 1 + Layer 3: enforcement / 차단 훅
    ├── tdd-gate.sh        — L1: Claude Code PreToolUse — blocks Edit/Write without Red
    └── pre-commit         — L3: Git pre-commit — blocks commit without Red→Green cycle
```

## Three-Layer TDD Enforcement / 3레이어 TDD 강제

### Why three layers? / 왜 3개?

No single layer is sufficient. AI models find workarounds.
단일 레이어로는 불충분하다. AI 모델은 우회 경로를 찾는다.

| Layer | When / 차단 시점 | What / 역할 | Scope / 범위 |
|-------|-----------------|-------------|-------------|
| **L1: Claude Code Hook** | Before file edit / 파일 수정 전 | Blocks `src/` edits without Red evidence / Red 없이 구현 파일 수정 차단 | Claude Code only |
| **L2: Shell Scripts** | On command / 명령 실행 시 | Enforces Red→Green order via state file / 상태 파일로 순서 강제 | All AI tools / 모든 AI 도구 |
| **L3: Git Pre-commit** | On commit / 커밋 시 | Blocks commit without Red→Green cycle / 사이클 없이 커밋 차단 | All tools + humans / 모든 도구 + 사람 |

### State file: `.tdd-state`

All three layers communicate through this single file.
3개 레이어 모두 이 파일을 통해 소통한다.

```json
{
  "phase": "red",
  "red_complete": true,
  "green_complete": false,
  "last_red_at": "2026-04-07T10:30:00Z",
  "last_green_at": null,
  "test_command": "cargo test --test schedule_test",
  "failed_count": 3
}
```

### Dependencies / 의존성

```
L2 (Scripts) ── WRITES ──→ .tdd-state
L1 (Hook)    ── READS  ──→ .tdd-state → blocks Edit/Write
L3 (Git)     ── READS  ──→ .tdd-state → blocks commit
```

- **L2 is the core**: the only layer that writes state. Without it, L1 and L3 have nothing to read.
- **L1 is real-time defense**: blocks at the earliest point, but Claude Code only.
- **L3 is the universal safety net**: works with any tool, catches everything at commit time.

---

## Modes / 모드

Control how much the AI decides on its own.
AI가 어디까지 혼자 판단하는지 제어한다.

| Mode | File | Description |
|------|------|-------------|
| **suggest** (default) | `modes/suggest.md` | Asks before every judgment call / 판단마다 확인 |
| **drive** | `modes/drive.md` | Autonomous for minor decisions / 사소한 판단은 자율 |

### Switching modes / 모드 전환

```
이번 작업은 suggest로 진행해
Switch to drive mode
커스텀 모드 만들어줘
```

### Capability Matrix / 능력 매트릭스

22 capabilities in 6 categories. Each is O (autonomous) or X (requires confirmation).
6개 카테고리, 22개 능력. 각각 O(자율) 또는 X(확인 필수).

#### Fixed O — Always autonomous / 항상 자율

| Category | Capability | Reason |
|----------|-----------|--------|
| Exploration | File/code reading | Mechanical, no judgment |
| Exploration | Code search (grep, glob) | Mechanical, no judgment |
| Exploration | Project docs | Mechanical, no judgment |
| Exploration | Web search | Mechanical, no judgment |
| Tech choice | Naming | Convention-based |
| Execution | Instructed code changes | User-specified work |
| Execution | Build/test commands | Verification |
| Execution | Formatting/lint | Convention-based |

#### Fixed X — Always requires confirmation / 항상 확인

| Category | Capability | Reason |
|----------|-----------|--------|
| Tech choice | Substitute selection | Risk of wrong tool replacement |
| Process | Scope expansion/reduction | Changes work direction |
| Process | Exception protocol | Workflow order change needs approval |
| Side tasks | Unrequested refactoring | User didn't ask for it |
| Side tasks | Unrelated bug fixes | User didn't ask for it |

#### Configurable — 13 capabilities / 설정 가능 13개

| # | Category | Capability | suggest | drive |
|---|----------|-----------|---------|-------|
| 1 | Requirements | Ambiguous instruction interpretation | X | O |
| 2 | Requirements | Scope judgment | X | O |
| 3 | Requirements | Implicit requirement inference | X | O |
| 4 | Requirements | Priority decision | X | O |
| 5 | Tech choice | Tool/library selection | X | O |
| 6 | Tech choice | Architecture/pattern selection | X | O |
| 7 | Tech choice | File structure/location | X | O |
| 8 | Execution | Uninstructed file creation | X | O |
| 9 | Process | Workflow phase transition | X | O |
| 10 | Process | Obstacle workaround | X | O |
| 11 | Process | Work completion judgment | X | O |
| 12 | Side tasks | Memory saving | X | O |
| 13 | Side tasks | Related doc updates | X | O |

---

## Custom Mode Creation / 커스텀 모드 생성

Say "커스텀 모드 만들어줘" or "Create a custom mode".

### Step 1 — Questions / 질문

13 configurable capabilities, one by one:

```
1/13 — Requirements
When instructions are ambiguous, proceed autonomously? (O/X)
```

### Step 2 — Summary / 요약

```
# | Capability              | Setting
1 | Ambiguous instructions  | O
2 | Scope judgment          | X
...
```

### Step 3 — Name / 이름

```
Name this mode:
```

### Step 4 — Save / 저장

Saved as `modes/{name}.md`. Added to the mode list above.

---

## Behavior Rules / 행동 규칙

### When X (confirmation required)

1. **Stop** — Do not make the decision alone
2. **Present options** — List available choices
3. **Wait for confirmation** — Proceed only after user selects
4. **No "it's more efficient" shortcuts** — Suppress completion bias

### When O (autonomous)

1. **Proceed** — Execute without asking
2. **Report** — Include what was decided in the result
3. **Justify** — Leave a one-line reason for the decision

---

## Requirements / 요구사항

- `jq` (JSON processor) — pre-installed on macOS
- `bash` 4.0+
- `git`
- Claude Code (for Layer 1 only)

## License

MIT
