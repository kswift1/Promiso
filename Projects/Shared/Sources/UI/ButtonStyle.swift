import SwiftUI

// MARK: - Adaptive Button Modifiers

public extension View {
  /// Primary 버튼 스타일 (iOS 26: glassProminent, 이전: 파란색 배경)
  func adaptivePrimaryButton() -> some View {
    if #available(iOS 26.0, *) {
      return AnyView(self.buttonStyle(.glassProminent))
    } else {
      return AnyView(
        self
          .background(Color.blue)
          .foregroundStyle(.white)
          .clipShape(RoundedRectangle(cornerRadius: 14))
      )
    }
  }
  
  /// Secondary 버튼 스타일 (iOS 26: glass, 이전: 회색 배경)
  func adaptiveSecondaryButton() -> some View {
    if #available(iOS 26.0, *) {
      return AnyView(self.buttonStyle(.glass))
    } else {
      return AnyView(
        self
          .background(Color(.white))
          .foregroundStyle(.blue)
          .clipShape(RoundedRectangle(cornerRadius: 14))
      )
    }
  }
  
  /// Destructive 버튼 스타일 (iOS 26: glassProminent, 이전: 빨간색 배경)
  func adaptiveDestructiveButton() -> some View {
    if #available(iOS 26.0, *) {
      return AnyView(
        self
          .buttonStyle(.glassProminent)
          .tint(.red)
      )
        
    } else {
      return AnyView(
        self
          .background(Color.red)
          .foregroundStyle(.white)
          .clipShape(RoundedRectangle(cornerRadius: 14))
      )
    }
  }
}

// MARK: - Usage

struct ButtonExamples: View {
  @State private var showCreateGroup = false
  @State private var showJoinGroup = false
  
  var body: some View {
    VStack(spacing: 12) {
      // ✅ Primary Button
      Button(action: { showCreateGroup = true }) {
        HStack(spacing: 8) {
          Image(systemName: "plus.circle.fill")
            .font(.title3)
          Text("그룹 만들기")
            .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
      }
      .adaptivePrimaryButton()
      
      // ✅ Secondary Button
      Button(action: { showJoinGroup = true }) {
        HStack(spacing: 8) {
          Image(systemName: "link.circle.fill")
            .font(.title3)
          Text("초대 코드로 참여하기")
            .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
      }
      .adaptiveSecondaryButton()
      
      // ✅ Destructive Button
      Button(action: {}) {
        HStack(spacing: 8) {
          Image(systemName: "trash.fill")
            .font(.title3)
          Text("삭제하기")
            .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
      }
      .adaptiveDestructiveButton()
    }
    .padding(.horizontal, 40)
  }
}

#Preview {
  ButtonExamples()
}
