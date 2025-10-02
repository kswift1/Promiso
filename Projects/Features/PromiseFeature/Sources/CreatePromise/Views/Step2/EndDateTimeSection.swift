import SwiftUI
import ComposableArchitecture

struct EndDateTimeSection: View {
  let store: StoreOf<CreatePromise.Feature>
  var scrollProxy: ScrollViewProxy? = nil

  var body: some View {
    SectionPlaceHolder(
      placeHolderTitle: "종료 시간",
      isRequired: false,
      placeHolderAccessory: {
        Toggle("", isOn: Binding(
          get: { store.useEndTime },
          set: { _ in
            store.send(.toggleUseEndTime, animation: .spring(response: 0.4, dampingFraction: 0.85))
          }
        ))
        .labelsHidden()
      },
      content: {
        VStack {
          // Duration Picker
          if store.useEndTime {
            EndTimePicker(
              startDate: store.promiseProposal.startedAt,
              endDate: Binding(
                get: {
                  store.promiseProposal.endedAt ?? store.promiseProposal.startedAt.addingTimeInterval(7200)
                },
                set: { store.send(.setEndDate($0)) }
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
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy.M.d."
    return formatter.string(from: endDate)
  }
  
  private var formattedTime: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "a h:mm"
    formatter.locale = Locale(identifier: "ko_KR")
    return formatter.string(from: endDate)
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
          .foregroundColor(.blue)
        Text(durationText)
          .font(.system(size: 13))
          .foregroundColor(.blue)
      }
      .padding(.top, 8)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

// MARK: - Previews

#Preview("Toggle OFF") {
  EndDateTimeSection(
    store: Store(
      initialState: CreatePromise.Feature.State(
        promiseProposal: PromiseProposal(
          title: "영화 관람",
          emoji: "🍿",
          group: .init(
            id: "g1",
            emoji: "👥",
            title: "지민과 나",
            memberCount: 2
          ),
          startedAt: Date().addingTimeInterval(7200),
          endedAt: nil,
          minimumParticipants: 2
        )
      )
    ) {
      CreatePromise.Feature()
    }
  )
  .padding()
}

#Preview("Toggle ON - 2시간") {
  EndDateTimeSection(
    store: Store(
      initialState: CreatePromise.Feature.State(
        promiseProposal: PromiseProposal(
          title: "영화 관람",
          emoji: "🍿",
          group: .init(
            id: "g1",
            emoji: "👥",
            title: "지민과 나",
            memberCount: 2
          ),
          startedAt: Date().addingTimeInterval(7200),
          endedAt: Date().addingTimeInterval(7200 + 7200),
          minimumParticipants: 2
        )
      )
    ) {
      CreatePromise.Feature()
    }
  )
  .padding()
}

#Preview("Toggle ON - 1일 5시간 30분") {
  EndDateTimeSection(
    store: Store(
      initialState: CreatePromise.Feature.State(
        promiseProposal: PromiseProposal(
          title: "해외 출장",
          emoji: "✈️",
          group: .init(
            id: "g1",
            emoji: "👥",
            title: "지민과 나",
            memberCount: 2
          ),
          startedAt: Date().addingTimeInterval(7200),
          endedAt: Date().addingTimeInterval(7200 + 86400 + 19800),
          minimumParticipants: 2
        )
      )
    ) {
      CreatePromise.Feature()
    }
  )
  .padding()
}

#Preview("날짜 피커 펼쳐짐") {
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

#Preview("시간 피커 펼쳐짐") {
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

#Preview("다크모드") {
  VStack(spacing: 24) {
    EndDateTimeSection(
      store: Store(
        initialState: CreatePromise.Feature.State(
          promiseProposal: PromiseProposal(
            title: "저녁 식사",
            emoji: "🍽️",
            group: .init(
              id: "g1",
              emoji: "👥",
              title: "지민과 나",
              memberCount: 2
            ),
            startedAt: Date().addingTimeInterval(7200),
            endedAt: Date().addingTimeInterval(7200 + 7200),
            minimumParticipants: 2
          )
        )
      ) {
        CreatePromise.Feature()
      }
    )
  }
  .padding()
  .preferredColorScheme(.dark)
}

#Preview("전체 폼") {
  ScrollView {
    VStack(spacing: 24) {
      Text("Step 2 - 날짜/시간")
        .font(.title2)
        .fontWeight(.bold)
        .frame(maxWidth: .infinity, alignment: .leading)
      
      SectionPlaceHolder(
        placeHolderTitle: "시작 시간",
        isRequired: true
      ) {
        // 시작 시간 예시
        HStack(spacing: 16) {
          HStack(spacing: 8) {
            Image(systemName: "calendar")
              .font(.system(size: 16))
              .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
              Text("날짜")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
              Text("2024.10.15.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          
          Divider()
            .frame(height: 32)
          
          HStack(spacing: 8) {
            Image(systemName: "clock")
              .font(.system(size: 16))
              .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
              Text("시간")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
              Text("오후 7:00")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
      }
      
      EndDateTimeSection(
        store: Store(
          initialState: CreatePromise.Feature.State(
            promiseProposal: PromiseProposal(
              title: "카페 미팅",
              emoji: "☕",
              group: .init(
                id: "g1",
                emoji: "👥",
                title: "지민과 나",
                memberCount: 2
              ),
              startedAt: Date().addingTimeInterval(7200),
              endedAt: Date().addingTimeInterval(7200 + 5400),
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

#Preview("인터랙티브 테스트") {
  struct PreviewWrapper: View {
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(7200)
    
    var body: some View {
      ScrollView {
        VStack(spacing: 24) {
          Text("시작 시간과 종료 시간 비교")
            .font(.headline)
          
          VStack(alignment: .leading, spacing: 8) {
            Text("시작 시간")
              .font(.caption)
              .foregroundColor(.secondary)
            
            // 시작 시간 (InlineDateTimePicker 예시)
            HStack(spacing: 16) {
              HStack(spacing: 8) {
                Image(systemName: "calendar")
                  .font(.system(size: 16))
                  .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                  Text("날짜")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                  Text(startDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                }
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              
              Divider()
                .frame(height: 32)
              
              HStack(spacing: 8) {
                Image(systemName: "clock")
                  .font(.system(size: 16))
                  .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                  Text("시간")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                  Text(startDate.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                }
              }
              .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
          }
          
          Divider()
          
          VStack(alignment: .leading, spacing: 8) {
            Text("종료 시간")
              .font(.caption)
              .foregroundColor(.secondary)
            
            EndTimePicker(
              startDate: startDate,
              endDate: $endDate
            )
          }
        }
        .padding()
      }
    }
  }
  
  return PreviewWrapper()
}
