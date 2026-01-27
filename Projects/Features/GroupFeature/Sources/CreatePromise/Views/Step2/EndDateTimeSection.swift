import SwiftUI
import Clients
import ComposableArchitecture
import ResourceKit

struct EndDateTimeSection: View {
  let store: StoreOf<CreatePromise.Feature>
  var scrollProxy: ScrollViewProxy? = nil

  private var useEndTime: Bool {
    store.state.promise.endAt != nil
  }

  var body: some View {
    SectionPlaceHolder(
      placeHolderTitle: "종료 시간",
      placeHolderAccessory: {
        Toggle("", isOn: Binding(
          get: { useEndTime },
          set: { _ in
            store.send(.view(.toggleUseEndTime), animation: .spring(response: 0.4, dampingFraction: 0.85))
          }
        ))
        .labelsHidden()
      },
      content: {
        VStack {
          // Duration Picker
          if useEndTime {
            EndTimePicker(
              startDate: store.promise.startAt,
              endDate: Binding(
                get: {
                  store.promise.endAt ?? store.promise.startAt.addingTimeInterval(7200)
                },
                set: { store.send(.view(.setEndDate($0))) }
              ),
              scrollProxy: scrollProxy,
              scrollToId: "endDateTime"
            )
          }
        }
      }
    )
  }
}

// MARK: - End Time Picker
struct EndTimePicker: View {
  let startDate: Date
  @Binding var endDate: Date
  @State private var expandedSection: ExpandedSection? = nil
  @State private var isDatePressed = false
  @State private var isTimePressed = false
  var scrollProxy: ScrollViewProxy? = nil
  var scrollToId: String? = nil

  enum ExpandedSection {
    case date, time
  }
  
  private var currentDuration: TimeInterval {
    endDate.timeIntervalSince(startDate)
  }
  
  private var durationText: String {
    let days = Int(currentDuration / 86400)
    let hours = Int((currentDuration.truncatingRemainder(dividingBy: 86400)) / 3600)
    let minutes = Int((currentDuration.truncatingRemainder(dividingBy: 3600)) / 60)
    
    var parts: [String] = []
    
    if days > 0 {
      parts.append("\(days)일")
    }
    if hours > 0 {
      parts.append("\(hours)시간")
    }
    if minutes > 0 {
      parts.append("\(minutes)분")
    }
    
    if parts.isEmpty {
      return "총 0분"
    }
    
    return "총 " + parts.joined(separator: " ")
  }
  
  private var formattedDate: String {
    KoreanDateFormatters.dateDot.string(from: endDate)
  }

  private var formattedTime: String {
    endDate.formattedTime
  }
  
  var body: some View {
    VStack(spacing: 0) {
      // 통합 버튼 (시작 시간과 동일한 스타일)
      HStack(spacing: 16) {
        // 날짜 영역
        Button(action: {
          withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            if expandedSection == .date {
              expandedSection = nil
            } else {
              expandedSection = .date
              // 달력이 펼쳐질 때 해당 섹션으로 스크롤
              if let scrollProxy = scrollProxy, let scrollToId = scrollToId {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                  withAnimation {
                    scrollProxy.scrollTo(scrollToId, anchor: .top)
                  }
                }
              }
            }
          }
        }) {
          HStack(spacing: 8) {
            Image(systemName: "calendar")
              .font(.system(size: 16))
              .foregroundColor(Color.pmindigo.n500)

            VStack(alignment: .leading, spacing: 2) {
              Text("날짜")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
              Text(formattedDate)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .scaleEffect(isDatePressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isDatePressed)
        .sensoryFeedback(.selection, trigger: expandedSection == .date)
        .simultaneousGesture(
          DragGesture(minimumDistance: 0)
            .onChanged { _ in isDatePressed = true }
            .onEnded { _ in isDatePressed = false }
        )

        Divider()
          .frame(height: 32)

        // 시간 영역
        Button(action: {
          withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            if expandedSection == .time {
              expandedSection = nil
            } else {
              expandedSection = .time
              // 시간 피커가 펼쳐질 때 해당 섹션으로 스크롤
              if let scrollProxy = scrollProxy, let scrollToId = scrollToId {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                  withAnimation {
                    scrollProxy.scrollTo(scrollToId, anchor: .top)
                  }
                }
              }
            }
          }
        }) {
          HStack(spacing: 8) {
            Image(systemName: "clock")
              .font(.system(size: 16))
              .foregroundColor(Color.pmindigo.n500)

            VStack(alignment: .leading, spacing: 2) {
              Text("시간")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
              Text(formattedTime)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .scaleEffect(isTimePressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isTimePressed)
        .sensoryFeedback(.selection, trigger: expandedSection == .time)
        .simultaneousGesture(
          DragGesture(minimumDistance: 0)
            .onChanged { _ in isTimePressed = true }
            .onEnded { _ in isTimePressed = false }
        )
      }
      .padding(16)
      .background(Color(.systemGray6))
      .clipShape(RoundedRectangle(cornerRadius: 12))
      
      // DatePicker (선택된 섹션에 따라)
      if let section = expandedSection {
        Group {
          if section == .date {
            DatePicker(
              "",
              selection: $endDate,
              in: startDate...,
              displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .environment(\.locale, Locale(identifier: "ko_KR"))
            .frame(width: 320)
            .scaleEffect(1.05)
          } else {
            DatePicker(
              "",
              selection: $endDate,
              in: startDate...,
              displayedComponents: [.hourAndMinute]
            )
            .datePickerStyle(.wheel)
            .environment(\.locale, Locale(identifier: "ko_KR"))
            .labelsHidden()
          }
        }
        .padding(.top, 12)
        .transition(.asymmetric(
          insertion: .scale(scale: 0.95, anchor: .top).combined(with: .opacity),
          removal: .scale(scale: 0.95, anchor: .top).combined(with: .opacity)
        ))
      }
      
      // 소요 시간 표시
      HStack(spacing: 6) {
        Image(systemName: "arrow.right")
          .font(.system(size: 11))
          .foregroundColor(Color.pmindigo.n500)
        Text(durationText)
          .font(.system(size: 13))
          .foregroundColor(Color.pmindigo.n500)
      }
      .padding(.top, 8)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

// MARK: - Previews

#Preview("EndTimePicker") {
  struct PreviewWrapper: View {
    @State private var endDate = Date().addingTimeInterval(10800)

    var body: some View {
      ScrollView {
        EndTimePicker(
          startDate: Date().addingTimeInterval(7200),
          endDate: $endDate
        )
        .padding()
      }
    }
  }

  return PreviewWrapper()
}
