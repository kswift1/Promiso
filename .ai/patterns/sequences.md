---
updated: 2025-01-29
total_sequences: 0
---

# 명령어 시퀀스 패턴

> 연속으로 실행되는 명령어 시퀀스를 추적합니다.
> 3회 이상 반복된 시퀀스는 Skill 생성 대상입니다.

## 활성 시퀀스

| ID | 시퀀스 | 횟수 | Skill 상태 |
|----|--------|------|-----------|
| - | (아직 감지된 시퀀스 없음) | - | - |

## 예상 시퀀스 (관찰 대상)

### Git 워크플로우
```
git status → git add → git commit → git push
```
- **예상 빈도**: 높음
- **제안 Skill**: /quick-push

### Tuist 빌드
```
tuist clean → tuist generate → tuist build
```
- **예상 빈도**: 중간
- **제안 Skill**: /rebuild

### Feature 개발 플로우
```
make feature → Edit → tuist generate → tuist build
```
- **예상 빈도**: 중간
- **제안 Skill**: (이미 /new-feature에 포함)

---

## 시퀀스 상세

<!-- 감지된 시퀀스의 상세 정보가 여기에 추가됩니다 -->

### 템플릿

```markdown
### SEQ-{ID}: {시퀀스명}

**명령어 순서**:
1. `{command1}`
2. `{command2}`
3. `{command3}`

- **첫 감지**: {날짜}
- **총 횟수**: {N}회
- **제안 Skill**: /{skill-name}
- **상태**: 🆕 제안됨 / ✅ 생성됨 / ❌ 거부됨
```
