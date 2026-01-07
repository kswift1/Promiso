import SwiftUI
import Clients
import ComposableArchitecture

// MARK: - Inline DateTimePicker with Separate Touch Areas
struct InlineDateTimePicker: View {
  @Binding var date: Date
  @State private var expandedSection: ExpandedSection? = nil
  var minimumDate: Date = Date()
  var scrollProxy: ScrollViewProxy? = nil
  var scrollToId: String? = nil

  enum ExpandedSection {
    case date, time
  }
  
  private var formattedDate: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy.M.d."
    return formatter.string(from: date)
  }
  
  private var formattedTime: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "a h:mm"
    formatter.locale = Locale(identifier: "ko_KR")
    return formatter.string(from: date)
  }
  
  var body: some View {
    VStack(spacing: 0) {
      // 통합 버튼 (내부에서 영역 구분)
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
              .foregroundColor(.blue)
            
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
        }
        .buttonStyle(PlainButtonStyle())
        
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
              .foregroundColor(.blue)
            
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
        }
        .buttonStyle(PlainButtonStyle())
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
              selection: $date,
              in: minimumDate...,
              displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .environment(\.locale, Locale(identifier: "ko_KR"))
            // Bugfix for AutoLayout-Issue (https://stackoverflow.com/questions/73475000/datepicker-with-graphical-style-breaks-layout-constraints-on-ios-16-0)
            .frame(width: 320)
            .scaleEffect(1.05)
          } else {
            DatePicker(
              "",
              selection: $date,
              in: minimumDate...,
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
    }
  }
}

// MARK: - StartDateTimeSection
struct StartDateTimeSection: View {
  let store: StoreOf<CreatePromise.Feature>
  var scrollProxy: ScrollViewProxy? = nil

  private var timeUntilStart: TimeInterval {
    store.promise.startAt.timeIntervalSinceNow
  }

  private var showWarning: Bool {
    timeUntilStart < 3600 && timeUntilStart > 0
  }

  var body: some View {
    SectionPlaceHolder(
      placeHolderTitle: "시작 시간",
      isRequired: true
    ) {
      VStack(spacing: 0) {
        InlineDateTimePicker(
          date: Binding(
            get: { store.promise.startAt },
            set: { store.send(.view(.setStartDate($0))) }
          ),
          scrollProxy: scrollProxy,
          scrollToId: "startDateTime"
        )
        
        // 경고 메시지
        if showWarning {
          HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
              .font(.system(size: 14))
              .foregroundColor(.orange)
            
            Text("시작 시간이 1시간 이내입니다. 멤버들이 응답할 시간이 부족할 수 있습니다.")
              .font(.system(size: 13))
              .foregroundColor(.orange)
              .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 0)
          }
          .padding(12)
          .background(Color.orange.opacity(0.1))
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .padding(.top, 8)
        }
      }
    }
  }
}

// MARK: - Previews

#Preview("DateTimePicker") {
  struct PreviewWrapper: View {
    @State private var date = Date().addingTimeInterval(7200)

    var body: some View {
      VStack(spacing: 24) {
        InlineDateTimePicker(date: $date)
      }
      .padding()
    }
  }

  return PreviewWrapper()
}
