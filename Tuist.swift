import ProjectDescription

/// Tuist 전역 설정
///
/// ## TUIST_ENV 환경변수
///
/// 프로젝트 생성 시 환경을 선택할 수 있습니다:
///
/// ```bash
/// # Dev 환경 생성 (기본값)
/// tuist generate
/// # 또는 명시적으로
/// TUIST_ENV=dev tuist generate
///
/// # Stage 환경만 생성 (PromisoStage + Widget)
/// TUIST_ENV=stage tuist generate
///
/// # Prod 환경만 생성 (Promiso + Widget)
/// TUIST_ENV=prod tuist generate
/// ```
///
/// 장점:
/// - 불필요한 타겟을 로딩하지 않아 빠른 빌드
/// - 명확한 환경 분리
/// - CI/CD에서 환경별 빌드 간소화
let config = Config(
  compatibleXcodeVersions: .all
)
