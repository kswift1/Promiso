// MARK: - Haptic Feedback Usage Examples

import Foundation

/// 햅틱 피드백 사용 예시들
/// 이 파일은 개발자들이 적절한 햅틱을 선택할 수 있도록 가이드를 제공합니다.
public enum HapticFeedbackExamples {
  
  /// UI 인터랙션별 권장 햅틱 패턴
  public enum UIInteractions {
    
    /// 일반적인 버튼 탭 (예: 탭바, 목록 항목 선택)
    public static func buttonTap() async {
      // TODO: HapticFeedback 의존성 통합 후 활성화
      // @Dependency(\.hapticFeedback) var hapticFeedback
      // await hapticFeedback.buttonTap()
    }
    
    /// 토글 스위치나 체크박스
    public static func toggle() async {
      // TODO: HapticFeedback 의존성 통합 후 활성화
      // @Dependency(\.hapticFeedback) var hapticFeedback
      // await hapticFeedback.toggle()
    }
    
    /// 중요한 액션 확인 (예: 약속 생성, 설정 저장)
    public static func confirm() async {
      // TODO: HapticFeedback 의존성 통합 후 활성화
      // @Dependency(\.hapticFeedback) var hapticFeedback
      // await hapticFeedback.confirm()
    }
    
    /// 파괴적 액션 (예: 삭제, 취소)
    public static func destructive() async {
      // TODO: HapticFeedback 의존성 통합 후 활성화
      // @Dependency(\.hapticFeedback) var hapticFeedback
      // await hapticFeedback.destructive()
    }
    
    /// 성공 알림 (예: 약속 생성 완료)
    public static func success() async {
      // TODO: HapticFeedback 의존성 통합 후 활성화
      // @Dependency(\.hapticFeedback) var hapticFeedback
      // await hapticFeedback.success()
    }
    
    /// 경고 알림 (예: 필드 검증 실패)
    public static func warning() async {
      // TODO: HapticFeedback 의존성 통합 후 활성화
      // @Dependency(\.hapticFeedback) var hapticFeedback
      // await hapticFeedback.warning()
    }
    
    /// 에러 알림 (예: 네트워크 오류)
    public static func error() async {
      // TODO: HapticFeedback 의존성 통합 후 활성화
      // @Dependency(\.hapticFeedback) var hapticFeedback
      // await hapticFeedback.error()
    }
  }
  
  /// Promise 앱 특화 햅틱 패턴
  public enum PromiseApp {
    
    /// 약속 생성 완료
    public static func promiseCreated() async {
      // TODO: HapticFeedback 의존성 통합 후 활성화
      // @Dependency(\.hapticFeedback) var hapticFeedback
      // await hapticFeedback.success()
    }
    
    /// 약속 참가
    public static func promiseJoined() async {
      // TODO: HapticFeedback 의존성 통합 후 활성화
      // @Dependency(\.hapticFeedback) var hapticFeedback
      // await hapticFeedback.medium()
    }
    
    /// 약속 완료
    public static func promiseCompleted() async {
      // TODO: HapticFeedback 의존성 통합 후 활성화
      // @Dependency(\.hapticFeedback) var hapticFeedback
      // await hapticFeedback.success()
    }
    
    /// 약속 취소/삭제
    public static func promiseCancelled() async {
      // TODO: HapticFeedback 의존성 통합 후 활성화
      // @Dependency(\.hapticFeedback) var hapticFeedback
      // await hapticFeedback.destructive()
    }
    
    /// 알림 도착
    public static func notificationReceived() async {
      // TODO: HapticFeedback 의존성 통합 후 활성화
      // @Dependency(\.hapticFeedback) var hapticFeedback
      // await hapticFeedback.light()
    }
    
    /// 그룹 생성
    public static func groupCreated() async {
      // TODO: HapticFeedback 의존성 통합 후 활성화
      // @Dependency(\.hapticFeedback) var hapticFeedback
      // await hapticFeedback.success()
    }
    
    /// 멤버 초대
    public static func memberInvited() async {
      // TODO: HapticFeedback 의존성 통합 후 활성화
      // @Dependency(\.hapticFeedback) var hapticFeedback
      // await hapticFeedback.medium()
    }
    
    /// 페이지 전환 (중요한 화면)
    public static func pageTransition() async {
      // TODO: HapticFeedback 의존성 통합 후 활성화
      // @Dependency(\.hapticFeedback) var hapticFeedback
      // await hapticFeedback.selection()
    }
    
    /// 리프레시 액션
    public static func refresh() async {
      // TODO: HapticFeedback 의존성 통합 후 활성화
      // @Dependency(\.hapticFeedback) var hapticFeedback
      // await hapticFeedback.light()
    }
  }
}

// MARK: - Usage in TCA Reducers

/*
// TCA Reducer에서 사용 예시:

@Reducer
public struct MyFeature {
  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .buttonTapped:
        return .run { _ in
          await HapticFeedbackExamples.UIInteractions.buttonTap()
        }
        
      case .promiseCreated:
        return .run { _ in
          await HapticFeedbackExamples.PromiseApp.promiseCreated()
        }
        
      case .deleteConfirmed:
        return .run { _ in
          await HapticFeedbackExamples.UIInteractions.destructive()
          // 실제 삭제 로직...
        }
      }
    }
  }
}
*/
