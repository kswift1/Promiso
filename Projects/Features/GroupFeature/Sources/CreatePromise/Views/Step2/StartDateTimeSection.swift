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
    store.promiseProposal.startedAt.timeIntervalSinceNow
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
            get: { store.promiseProposal.startedAt },
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

#Preview("접힌 상태") {
  struct PreviewWrapper: View {
    @State private var date = Date().addingTimeInterval(7200)
    
    var body: some View {
      VStack(spacing: 24) {
        Text("개별 터치 방식")
          .font(.headline)
        
        Text("날짜 또는 시간 영역을 각각 터치해보세요")
          .font(.caption)
          .foregroundColor(.secondary)
        
        InlineDateTimePicker(date: $date)
      }
      .padding()
    }
  }
  
  return PreviewWrapper()
}

#Preview("날짜 펼쳐진 상태") {
  struct PreviewWrapper: View {
    @State private var date = Date().addingTimeInterval(7200)
    
    var body: some View {
      ScrollView {
        VStack(spacing: 24) {
          Text("날짜 피커")
            .font(.headline)
          
          InlineDateTimePicker(date: $date)
        }
        .padding()
      }
    }
  }
  
  return PreviewWrapper()
}

#Preview("Section - 정상") {
  ScrollView {
    StartDateTimeSection(
      store: Store(
        initialState: CreatePromise.Feature.State(
          promiseProposal: PromiseProposal(
             title: "영화 관람",
            emoji: "🍿",
            group: .init(
              id: "g1",
              name: "지민과 나",
              maxMembers: 2,
              inviteCode: "PREVIEW",
              createdBy: "preview"
            ),
            startedAt: Date().addingTimeInterval(7200),
            minimumParticipants: 2
          )
        )
      ) {
        CreatePromise.Feature()
      }
    )
    .padding()
  }
}

#Preview("Section - 경고") {
  ScrollView {
    StartDateTimeSection(
      store: Store(
        initialState: CreatePromise.Feature.State(
          promiseProposal: PromiseProposal(
             title: "긴급 회의",
            emoji: "💼",
            group: .init(
              id: "g1",
              name: "지민과 나",
              maxMembers: 2,
              inviteCode: "PREVIEW",
              createdBy: "preview"
            ),
            startedAt: Date().addingTimeInterval(1800),
            minimumParticipants: 2
          )
        )
      ) {
        CreatePromise.Feature()
      }
    )
    .padding()
  }
}

#Preview("다크모드") {
  struct PreviewWrapper: View {
    @State private var date = Date().addingTimeInterval(3600)
    
    var body: some View {
      ScrollView {
        VStack(spacing: 24) {
          InlineDateTimePicker(date: $date)
          
          StartDateTimeSection(
            store: Store(
              initialState: CreatePromise.Feature.State(
                promiseProposal: PromiseProposal(
                   title: "저녁 식사",
                  emoji: "🍽️",
                  group: .init(
                    id: "g1",
                    name: "지민과 나",
                    maxMembers: 2,
                    inviteCode: "PREVIEW",
                    createdBy: "preview"
                  ),
                  startedAt: date,
                  minimumParticipants: 2
                )
              )
            ) {
              CreatePromise.Feature()
            }
          )
        }
        .padding()
      }
    }
  }
  
  return PreviewWrapper()
    .preferredColorScheme(.dark)
}

#Preview("전체 폼") {
  ScrollView {
    VStack(spacing: 24) {
      Text("약속 만들기 - Step 2")
        .font(.title2)
        .fontWeight(.bold)
        .frame(maxWidth: .infinity, alignment: .leading)
      
      StartDateTimeSection(
        store: Store(
          initialState: CreatePromise.Feature.State(
            promiseProposal: PromiseProposal(
               title: "카페 미팅",
              emoji: "☕",
              group: .init(
                id: "g1",
                name: "지민과 나",
                maxMembers: 2,
                inviteCode: "PREVIEW",
                createdBy: "preview"
              ),
              startedAt: Date().addingTimeInterval(7200),
              minimumParticipants: 2
            )
          )
        ) {
          CreatePromise.Feature()
        }
      )
      
      SectionPlaceHolder(
        placeHolderTitle: "장소",
        isRequired: false
      ) {
        TextField("장소를 검색하세요", text: .constant(""))
          .padding(16)
          .background(Color(.systemGray6))
          .clipShape(RoundedRectangle(cornerRadius: 12))
      }
      
      SectionPlaceHolder(
        placeHolderTitle: "최소 참가 인원",
        isRequired: true
      ) {
        HStack {
          Text("2명")
            .font(.title3)
            .fontWeight(.semibold)
          Spacer()
        }
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
      }
    }
    .padding()
  }
}

#Preview("인터랙티브 테스트") {
  struct PreviewWrapper: View {
    @State private var date = Date().addingTimeInterval(7200)
    
    var body: some View {
      ScrollView {
        VStack(spacing: 24) {
          Text("각 영역을 개별로 터치해보세요")
            .font(.headline)
          
          InlineDateTimePicker(date: $date)
          
          Divider()
            .padding(.vertical, 8)
          
          VStack(alignment: .leading, spacing: 8) {
            Text("선택된 날짜/시간")
              .font(.caption)
              .foregroundColor(.secondary)
            Text(date.formatted(date: .long, time: .shortened))
              .font(.body)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
      }
    }
  }
  
  return PreviewWrapper()
}
