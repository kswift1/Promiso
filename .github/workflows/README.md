# GitHub Actions 워크플로우

Promiso 프로젝트의 CI/CD 워크플로우 설명입니다.

## 사용 예시

### iOS 빌드 워크플로우에서 xcconfig 생성

```yaml
name: iOS Build

on:
  push:
    branches: [main, develop]
    paths:
      - 'Projects/**'
      - 'Tuist/**'
      - '.github/workflows/ios-build.yml'

jobs:
  build:
    runs-on: macos-14

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: '16.0'

      - name: Install Tuist
        run: |
          curl -Ls https://install.tuist.io | bash

      - name: Generate xcconfig files
        env:
          GOOGLE_CLIENT_ID_DEV: ${{ secrets.GOOGLE_CLIENT_ID_DEV }}
          GOOGLE_REVERSED_CLIENT_ID_DEV: ${{ secrets.GOOGLE_REVERSED_CLIENT_ID_DEV }}
          KAKAO_NATIVE_APP_KEY_DEV: ${{ secrets.KAKAO_NATIVE_APP_KEY_DEV }}
          KAKAO_REST_API_KEY_DEV: ${{ secrets.KAKAO_REST_API_KEY_DEV }}
          GOOGLE_CLIENT_ID_STAGE: ${{ secrets.GOOGLE_CLIENT_ID_STAGE }}
          GOOGLE_REVERSED_CLIENT_ID_STAGE: ${{ secrets.GOOGLE_REVERSED_CLIENT_ID_STAGE }}
          KAKAO_NATIVE_APP_KEY_STAGE: ${{ secrets.KAKAO_NATIVE_APP_KEY_STAGE }}
          KAKAO_REST_API_KEY_STAGE: ${{ secrets.KAKAO_REST_API_KEY_STAGE }}
          GOOGLE_CLIENT_ID_PROD: ${{ secrets.GOOGLE_CLIENT_ID_PROD }}
          GOOGLE_REVERSED_CLIENT_ID_PROD: ${{ secrets.GOOGLE_REVERSED_CLIENT_ID_PROD }}
          KAKAO_NATIVE_APP_KEY_PROD: ${{ secrets.KAKAO_NATIVE_APP_KEY_PROD }}
          KAKAO_REST_API_KEY_PROD: ${{ secrets.KAKAO_REST_API_KEY_PROD }}
        run: ./scripts/generate-xcconfig.sh

      - name: Generate Xcode project
        run: tuist generate

      - name: Build PromisoDev
        run: tuist build PromisoDev

      - name: Build PromisoStage
        run: tuist build PromisoStage

      - name: Build Promiso (Prod)
        run: tuist build Promiso
```

## 필수 GitHub Secrets

### iOS 빌드

```
# Dev Environment
GOOGLE_CLIENT_ID_DEV
GOOGLE_REVERSED_CLIENT_ID_DEV
KAKAO_NATIVE_APP_KEY_DEV
KAKAO_REST_API_KEY_DEV

# Stage Environment
GOOGLE_CLIENT_ID_STAGE
GOOGLE_REVERSED_CLIENT_ID_STAGE
KAKAO_NATIVE_APP_KEY_STAGE
KAKAO_REST_API_KEY_STAGE

# Production Environment
GOOGLE_CLIENT_ID_PROD
GOOGLE_REVERSED_CLIENT_ID_PROD
KAKAO_NATIVE_APP_KEY_PROD
KAKAO_REST_API_KEY_PROD
```

### Firebase Functions 배포

```
# Firebase 서비스 계정
FIREBASE_SERVICE_ACCOUNT_DEV
FIREBASE_SERVICE_ACCOUNT_STAGE
FIREBASE_SERVICE_ACCOUNT_PROD
```

## Secrets 설정 방법

1. GitHub 레포지토리 → **Settings**
2. **Secrets and variables** → **Actions**
3. **New repository secret** 클릭
4. Name과 Value 입력 후 **Add secret**

## 환경별 워크플로우 트리거

```yaml
# Dev 환경 - develop 브랜치
on:
  push:
    branches: [develop]

# Stage 환경 - staging 브랜치
on:
  push:
    branches: [staging]

# Production 환경 - main 브랜치, 태그
on:
  push:
    branches: [main]
    tags:
      - 'v*'
```

## TestFlight 배포 예시

```yaml
- name: Build for TestFlight
  run: |
    xcodebuild -workspace Promiso.xcworkspace \
      -scheme Promiso \
      -configuration Release \
      -archivePath ./build/Promiso.xcarchive \
      archive

- name: Export IPA
  run: |
    xcodebuild -exportArchive \
      -archivePath ./build/Promiso.xcarchive \
      -exportPath ./build \
      -exportOptionsPlist ./exportOptions.plist

- name: Upload to TestFlight
  env:
    APP_STORE_CONNECT_API_KEY_ID: ${{ secrets.APP_STORE_CONNECT_API_KEY_ID }}
    APP_STORE_CONNECT_API_ISSUER_ID: ${{ secrets.APP_STORE_CONNECT_API_ISSUER_ID }}
    APP_STORE_CONNECT_API_KEY: ${{ secrets.APP_STORE_CONNECT_API_KEY }}
  run: |
    xcrun altool --upload-app \
      -f ./build/Promiso.ipa \
      --apiKey $APP_STORE_CONNECT_API_KEY_ID \
      --apiIssuer $APP_STORE_CONNECT_API_ISSUER_ID
```

## 주의사항

- CI 환경에서는 `CI=true` 환경변수가 자동으로 설정되어 .env 파일을 사용하지 않습니다
- 모든 Secrets는 GitHub Secrets에서 관리하세요
- 절대로 Secrets 값을 로그에 출력하지 마세요
- Firebase 배포는 `firebase use <env>` 명령으로 환경을 전환합니다
