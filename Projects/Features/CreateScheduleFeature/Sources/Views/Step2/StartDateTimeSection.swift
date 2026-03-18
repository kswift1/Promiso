import SwiftUI
import Clients
import ComposableArchitecture
import PromisoShared
import ResourceKit

// MARK: - Inline DateTimePicker with Separate Touch Areas
struct InlineDateTimePicker: View {
  @Binding var date: Date
  @State private var expandedSection: ExpandedSection? = nil
  @State private var isDatePressed = false
  @State private var isTimePressed = false
  var minimumDate: Date = Date()
  var scrollProxy: ScrollViewProxy? = nil
  var scrollToId: String? = nil

  enum ExpandedSection {
    case date, time
  }
  
  private var formattedDate: String {
    LocalizedDateFormatters.dateDot.string(from: date)
  }

  private var formattedTime: String {
    date.formattedTime
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
              .foregroundColor(Color.pmindigo.n500)

            VStack(alignment: .leading, spacing: 2) {
              Text(LocalizedStrings.Common.date)
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
              Text(LocalizedStrings.Common.time)
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
              selection: $date,
              in: minimumDate...,
              displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .environment(\.locale, LocaleManager.appLocale)
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
            .environment(\.locale, LocaleManager.appLocale)
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
  let store: StoreOf<CreateSchedule.Feature>
  var scrollProxy: ScrollViewProxy? = nil

  private var timeUntilStart: TimeInterval {
    store.schedule.startAt.timeIntervalSinceNow
  }

  private var showWarning: Bool {
    timeUntilStart < 3600 && timeUntilStart > 0
  }

  var body: some View {
    SectionPlaceHolder(placeHolderTitle: LocalizedStrings.CreateSchedule.startTime) {
      VStack(spacing: 0) {
        InlineDateTimePicker(
          date: Binding(
            get: { store.schedule.startAt },
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
              .foregroundColor(Color.pmwarning.n600)

            Text(LocalizedStrings.CreateSchedule.startTimeWarning)
              .font(.system(size: 13))
              .foregroundColor(.secondary)
              .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
          }
          .padding(12)
          .background(Color.pmwarning.n50)
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
