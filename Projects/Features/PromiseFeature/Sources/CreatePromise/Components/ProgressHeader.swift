import SwiftUI

// MARK: - Progress Header Component
struct ProgressHeader: View {
  let currentStep: Int
  let totalSteps: Int
  let title: String
  var onDismiss: () -> Void
  
  var body: some View {
    VStack(spacing: 0) {
      // 상단 헤더 영역
      HStack {
        // 닫기 버튼
        Button(action: onDismiss) {
          Image(systemName: "xmark")
            .font(.system(size: 20, weight: .medium))
            .foregroundColor(.primary)
            .frame(width: 44, height: 44)
        }
        
        Spacer()
        
        // 제목
        Text(title)
          .font(.system(size: 18, weight: .bold))
          .foregroundColor(.primary)
        
        Spacer()
        
        Color.clear
          .frame(width: 44, height: 44)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      
      // 프로그레스 바
      HStack(spacing: 8) {
        ForEach(0...totalSteps-1, id: \.self) { step in
          ProgressSegment(isActive: step <= currentStep)
        }
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 12)
    }
    .background(Color(.systemBackground))
    .overlay(
      // 하단 구분선
      Rectangle()
        .fill(Color(.systemGray5))
        .frame(height: 1),
      alignment: .bottom
    )
  }
}

// MARK: - Progress Segment
struct ProgressSegment: View {
  @State private var hasAppeared: Bool = false
  let isActive: Bool

  private let firstDelay: TimeInterval = 0.2
  private let animationDuration: TimeInterval = 0.5

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        // 배경
        Rectangle()
          .fill(Color(.systemGray5))

        // 활성화된 프로그레스
        Rectangle()
          .fill(Color.blue)
          .frame(width: (isActive && hasAppeared) ? geometry.size.width : 0)
      }
    }
    .frame(height: 4)
    .clipShape(Capsule())
    .onAppear {
      withAnimation(.easeInOut(duration: animationDuration).delay(firstDelay)) {
        hasAppeared = true
      }
    }
    .onChange(of: isActive) { oldValue, newValue in
      guard hasAppeared else { return }
      if newValue {
        // 다음 단계로: 채워지는 애니메이션 (easeOut - 빠르게 시작, 천천히 끝)
        withAnimation(.easeOut(duration: animationDuration)) {
          // isActive 변경 시 자동으로 애니메이션
        }
      } else {
        // 이전 단계로: 비워지는 애니메이션 (easeIn - 천천히 시작, 빠르게 끝)
        withAnimation(.easeIn(duration: animationDuration)) {
          // isActive 변경 시 자동으로 애니메이션
        }
      }
    }
  }
}

// MARK: - Placeholder Content Views

enum CreatePromiseStep: Int, CaseIterable {
  case first
  case second
  case third
  
  mutating func next() {
    self += 1
  }
  
  mutating func previous() {
    self -= 1
  }
  
  // 현재 step에 정수를 더해서 다음 step으로 이동
  static func + (lhs: CreatePromiseStep, rhs: Int) -> CreatePromiseStep {
    let all = CreatePromiseStep.allCases
    let newIndex = min(max(lhs.rawValue + rhs, 0), all.count - 1)
    return all[newIndex]
  }
  
  // 현재 step에서 정수를 빼서 이전 step으로 이동
  static func - (lhs: CreatePromiseStep, rhs: Int) -> CreatePromiseStep {
    return lhs + (-rhs)
  }
  
  static func += (lhs: inout CreatePromiseStep, rhs: Int) {
    lhs = lhs + rhs
  }
  
  static func -= (lhs: inout CreatePromiseStep, rhs: Int) {
    lhs = lhs - rhs
  }
}

// MARK: - HeaderContentView
extension CreatePromiseStep {
  struct HeaderContentView: View {
    let title: String
    let subtitle: String
    
    var body: some View {
      VStack(alignment: .leading, spacing: 14) {
        Text(title)
          .font(.title2)
          .fontWeight(.bold)
        Text(subtitle)
          .font(.subheadline)
          .foregroundColor(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
  
  var contentView: HeaderContentView {
    HeaderContentView(title: title, subtitle: subtitle)
  }
  
  private var title: String {
    switch self {
    case .first: "어떤 약속인가요?"
    case .second: "언제, 어디서 만날까요?"
    case .third: "추가 설정"
    }
  }
  
  private var subtitle: String {
    switch self {
    case .first: "기본 정보를 입력해주세요"
    case .second: "날짜, 시간, 장소를 정해주세요"
    case .third: "알림과 상세 설명을 설정하세요"
    }
  }
}

// MARK: - BottomButtons
extension CreatePromiseStep {
  
}
