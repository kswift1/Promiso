# Worktree 사용 가이드

Git Worktree를 사용한 효율적인 Promiso 개발 워크플로우입니다.

## 📋 목차

1. [Worktree란?](#worktree란)
2. [디렉토리 구조](#디렉토리-구조)
3. [새 Worktree 생성](#새-worktree-생성)
4. [Firebase 설정 자동화](#firebase-설정-자동화)
5. [일상적인 워크플로우](#일상적인-워크플로우)
6. [문제 해결](#문제-해결)

---

## Worktree란?

Git Worktree는 **하나의 저장소에서 여러 브랜치를 동시에 체크아웃**할 수 있게 해주는 기능입니다.

### 장점

```
기존 방식 (git switch):
  develop 작업 중
    ↓
  git switch feature/new
    ↓
  😱 미완성 변경사항을 stash 해야 함
    ↓
  feature/new 작업
    ↓
  git switch develop (다시 복원)
```

```
Worktree 방식:
  ~/Developer/Promiso (develop)
  ~/Developer/Promiso-worktrees/feature/new (feature/new)

  ✅ 동시에 두 브랜치 작업 가능
  ✅ Xcode를 각각 열어두고 작업
  ✅ stash 필요 없음
```

---

## 디렉토리 구조

```
~/Developer/
├── Promiso/                           # Main (develop/main)
└── Promiso-worktrees/
    ├── feature/
    │   ├── add-notification/
    │   └── refactor-auth/
    ├── fix/
    │   └── login-bug/
    ├── develop/                       # develop 전용
    └── release/
        └── v1.0.0/

~/Developer/Promiso-Config/            # Firebase 설정 중앙 저장소
├── GoogleService-Info-Dev.plist
├── GoogleService-Info-Stage.plist
└── GoogleService-Info-Prod.plist
```

---

## 새 Worktree 생성

### 방법 1: 자동 (권장) ⭐

```bash
cd ~/Developer/Promiso
make new-worktree
```

**대화형 스크립트가 다음을 처리합니다:**

1. ✅ 브랜치 타입 선택 (feature/fix/refactor/develop/release)
2. ✅ 브랜치명 입력
3. ✅ Base 브랜치 선택 (develop/main)
4. ✅ Worktree 생성
5. ✅ Firebase 설정 파일 자동 링크
6. ✅ Tuist 의존성 설치 (`tuist install`)
7. ✅ Xcode 프로젝트 생성 (`tuist generate`)

**완료 후 바로 작업 가능!**

```bash
cd ~/Developer/Promiso-worktrees/feature/your-branch
open Promiso-Workspace.xcworkspace
```

---

### 방법 2: 수동

#### Step 1: Worktree 생성

```bash
cd ~/Developer/Promiso

# feature 브랜치
git worktree add -b feature/my-feature \
  ../Promiso-worktrees/feature/my-feature \
  develop

# fix 브랜치
git worktree add -b fix/login-bug \
  ../Promiso-worktrees/fix/login-bug \
  develop

# release 브랜치
git worktree add -b release/v1.1.0 \
  ../Promiso-worktrees/release/v1.1.0 \
  main
```

#### Step 2: Firebase 설정 파일 링크

```bash
cd ~/Developer/Promiso-worktrees/feature/my-feature
make setup-firebase
```

#### Step 3: Tuist 프로젝트 생성

```bash
tuist install   # 의존성 설치
tuist generate  # Xcode 프로젝트 생성
```

#### Step 4: Xcode 열기

```bash
open Promiso-Workspace.xcworkspace
```

---

## Firebase 설정 자동화

### 동작 원리

```
중앙 저장소 (한 곳):
~/Developer/Promiso-Config/
  ├── GoogleService-Info-Dev.plist
  ├── GoogleService-Info-Stage.plist
  └── GoogleService-Info-Prod.plist

모든 Worktree (심볼릭 링크):
~/Developer/Promiso/Projects/App/Resources-Dev/GoogleService-Info.plist
  → ~/Developer/Promiso-Config/GoogleService-Info-Dev.plist

~/Developer/Promiso-worktrees/*/Projects/App/Resources-Dev/GoogleService-Info.plist
  → ~/Developer/Promiso-Config/GoogleService-Info-Dev.plist
```

### 장점

1. **한 곳에서 관리** - 중앙 저장소만 업데이트하면 모든 worktree에 자동 반영
2. **새 worktree 즉시 사용** - `make setup-firebase` 한 번이면 끝
3. **Git에서 제외** - 보안 파일이 커밋되지 않음
4. **팀원 공유 간편** - 처음 한 번만 중앙 저장소에 파일 배치

### 수동 설정 (처음 한 번만)

Firebase Console에서 설정 파일을 다운로드한 경우:

```bash
# 중앙 저장소 생성
mkdir -p ~/Developer/Promiso-Config

# Firebase Console에서 다운로드한 파일 복사
cp ~/Downloads/GoogleService-Info.plist \
   ~/Developer/Promiso-Config/GoogleService-Info-Dev.plist

# Stage, Prod도 동일하게
# (각 환경별로 Firebase Console에서 다운로드)
```

---

## 일상적인 워크플로우

### 시나리오 1: 새 Feature 시작

```bash
# 1. 자동으로 Worktree 생성
cd ~/Developer/Promiso
make new-worktree

# 브랜치 타입: 1 (feature)
# 브랜치명: add-push-notification
# Base: 1 (develop)

# 2. 자동으로 모든 설정 완료
#    → Firebase 링크 ✅
#    → Tuist 의존성 ✅
#    → Xcode 프로젝트 ✅

# 3. 작업 시작
cd ~/Developer/Promiso-worktrees/feature/add-push-notification
open Promiso-Workspace.xcworkspace
```

### 시나리오 2: 급한 버그 수정 (다른 작업 중)

```bash
# 현재: feature/big-refactor 작업 중 (Xcode 열려있음)

# 1. 새 Worktree로 버그 수정
cd ~/Developer/Promiso
make new-worktree  # fix/urgent-login-bug

# 2. 새 Xcode로 버그 수정
cd ~/Developer/Promiso-worktrees/fix/urgent-login-bug
open Promiso-Workspace.xcworkspace

# 3. 버그 수정 완료 → PR 생성

# 4. 다시 feature/big-refactor로 돌아가기
#    → 기존 Xcode가 그대로 열려있음 ✅
```

### 시나리오 3: 작업 완료 후 정리

```bash
# PR이 머지되면 Worktree 삭제
git worktree remove ~/Developer/Promiso-worktrees/feature/add-push-notification

# 또는 디렉토리 삭제 후
rm -rf ~/Developer/Promiso-worktrees/feature/add-push-notification
git worktree prune
```

---

## 문제 해결

### Q1: "GoogleService-Info.plist not found" 에러

```bash
cd <your-worktree>
make setup-firebase
```

### Q2: Tuist 프로젝트가 생성되지 않음

```bash
# 1. 의존성 재설치
tuist clean
tuist install

# 2. 프로젝트 재생성
tuist generate
```

### Q3: Xcode에서 빌드 에러 (모듈 없음)

```bash
# 1. 파생 데이터 삭제
rm -rf ~/Library/Developer/Xcode/DerivedData

# 2. Tuist 캐시 클리어
tuist clean

# 3. 프로젝트 재생성
tuist generate
```

### Q4: 여러 Worktree에서 동시에 빌드할 때 충돌

Tuist의 DerivedData는 Worktree별로 분리되므로 **동시 빌드 가능**합니다.

단, Firebase Emulator는 **한 번에 하나만** 실행 가능합니다.

### Q5: Firebase 설정 파일이 변경되었을 때

중앙 저장소의 파일만 업데이트하면 됩니다:

```bash
# Firebase Console에서 새 파일 다운로드

# 중앙 저장소 덮어쓰기
cp ~/Downloads/GoogleService-Info.plist \
   ~/Developer/Promiso-Config/GoogleService-Info-Dev.plist

# 모든 Worktree에 자동 반영 ✅
```

---

## 유용한 명령어 모음

```bash
# 현재 Worktree 목록 확인
git worktree list

# Worktree 제거
git worktree remove <path>

# 삭제된 Worktree 정리 (Git 메타데이터 제거)
git worktree prune

# 특정 Worktree로 이동
cd ~/Developer/Promiso-worktrees/feature/<branch-name>

# Xcode 열기
open Promiso-Workspace.xcworkspace

# Firebase 설정 재링크
make setup-firebase

# 프로젝트 재생성
tuist generate
```

---

## 베스트 프랙티스

1. **Main 브랜치는 Worktree로 분리하지 않기** - `~/Developer/Promiso`를 main/develop용으로 유지
2. **Feature 브랜치는 Worktree 활용** - 동시 작업에 최적
3. **작업 완료 후 Worktree 삭제** - 디스크 공간 절약
4. **Firebase 설정은 중앙 저장소에서만 관리** - 일관성 유지
5. **자동 스크립트 활용** - `make new-worktree`로 빠른 설정

---

## 참고 자료

- [Git Worktree 공식 문서](https://git-scm.com/docs/git-worktree)
- [Tuist 문서](https://docs.tuist.io/)
- [Promiso 아키텍처 가이드](./ARCHITECTURE.md)
