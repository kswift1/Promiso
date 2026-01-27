// MARK: - CalendarFeatureExampleApp.swift
// Calendar Feature 개발과 테스트를 위한 독립 실행형 example 애플리케이션

import SwiftUI
import ComposableArchitecture
import CalendarFeature
import Clients

// MARK: - Example Application

@main
struct CalendarFeatureExampleApp: App {

  var body: some Scene {
    WindowGroup {
      NavigationStack {
        ExampleContentView()
          .navigationTitle("Calendar Examples")
          .navigationBarTitleDisplayMode(.large)
      }
    }
  }
}

// MARK: - Content View

private struct ExampleContentView: View {

  var body: some View {
    List {
      Section("캘린더 뷰 모드") {
        NavigationLink("주간 뷰 (Week)") {
          weekModeExample
        }

        NavigationLink("월간 뷰 (Month)") {
          monthModeExample
        }
      }

      Section("설명") {
        VStack(alignment: .leading, spacing: 8) {
          Text("기능")
            .font(.headline)

          Group {
            Text("• 주간/월간 뷰 토글")
            Text("• 날짜 선택 및 스와이프 이동")
            Text("• 약속 상태별 컬러 표시")
            Text("• 오늘 날짜로 빠른 이동")
            Text("• 약속 카드 탭 인터랙션")
          }
          .font(.caption)
          .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
      }

      Section("약속 상태 컬러") {
        HStack {
          statusDot(color: .yellow)
          Text("응답 대기 (Proposed)")
        }
        HStack {
          statusDot(color: .orange)
          Text("투표중 (Pending)")
        }
        HStack {
          statusDot(color: .green)
          Text("확정 (Confirmed)")
        }
        HStack {
          statusDot(color: Color(UIColor.systemGray3))
          Text("무산 (Rejected)")
        }
      }
    }
  }

  // MARK: - Example Views

  @ViewBuilder
  private var weekModeExample: some View {
    let store = Store(initialState: CalendarFeature.Feature.State(currentUser: Shared(value: .exampleUser), displayMode: .week)) {
      CalendarFeature.Feature()
    }

    CalendarFeature.RootView(store: store)
      .navigationTitle("주간 캘린더")
      .navigationBarTitleDisplayMode(.inline)
  }

  @ViewBuilder
  private var monthModeExample: some View {
    let store = Store(initialState: CalendarFeature.Feature.State(currentUser: Shared(value: .exampleUser), displayMode: .month)) {
      CalendarFeature.Feature()
    }

    CalendarFeature.RootView(store: store)
      .navigationTitle("월간 캘린더")
      .navigationBarTitleDisplayMode(.inline)
  }

  // MARK: - Helpers

  private func statusDot(color: Color) -> some View {
    Circle()
      .fill(color)
      .frame(width: 12, height: 12)
  }
}

// MARK: - SwiftUI Previews

#Preview("Example App") {
  NavigationStack {
    ExampleContentView()
      .navigationTitle("Calendar Examples")
  }
}

#Preview("Week Mode") {
  let store = Store(initialState: CalendarFeature.Feature.State(currentUser: Shared(value: .exampleUser), displayMode: .week)) {
    CalendarFeature.Feature()
  }

  CalendarFeature.RootView(store: store)
}

#Preview("Month Mode") {
  let store = Store(initialState: CalendarFeature.Feature.State(currentUser: Shared(value: .exampleUser), displayMode: .month)) {
    CalendarFeature.Feature()
  }

  CalendarFeature.RootView(store: store)
}
