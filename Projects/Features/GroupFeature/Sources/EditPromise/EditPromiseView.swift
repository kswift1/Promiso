import SwiftUI
import ComposableArchitecture
import Clients

extension EditPromise {
  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>
    @FocusState private var focusedField: FocusedField?

    enum FocusedField {
      case title, description
    }

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      NavigationStack {
        ScrollViewReader { proxy in
          ScrollView {
            VStack(alignment: .leading, spacing: 24) {
              // 제목 & 이모지 섹션
              titleSection

              // 설명 섹션
              descriptionSection

              // 시작 시간 섹션
              startDateSection(proxy: proxy)
                .id("startDateTime")

              // 종료 시간 섹션
              endDateSection(proxy: proxy)
                .id("endDateTime")

              // 최소 참가 인원 섹션
              minimumParticipantsSection
                .id("minimumParticipants")
            }
            .padding(16)
          }
        }
        .navigationTitle("약속 수정")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            Button("취소") {
              store.send(.view(.cancelTapped))
            }
          }

          ToolbarItem(placement: .topBarTrailing) {
            Button {
              store.send(.view(.saveTapped))
            } label: {
              if store.isUpdating {
                ProgressView()
                  .progressViewStyle(CircularProgressViewStyle())
              } else {
                Text("저장")
                  .fontWeight(.semibold)
              }
            }
            .disabled(!store.canSave || store.isUpdating)
          }
        }
        .alert(
          "수정 실패",
          isPresented: Binding(
            get: { store.updateError != nil },
            set: { if !$0 { store.send(.view(.clearError)) } }
          )
        ) {
          Button("확인", role: .cancel) {
            store.send(.view(.clearError))
          }
        } message: {
          if let error = store.updateError {
            Text(error.localizedDescription)
          }
        }
      }
    }

    // MARK: - Title Section

    private var titleSection: some View {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 4) {
          Text("제목")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.primary)

          Text("*")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.red)
        }

        HStack(spacing: 12) {
          // 이모지 버튼
          Button {
            // TODO: 이모지 피커 표시
          } label: {
            Text(store.editedPromise.displayEmoji)
              .font(.system(size: 32))
              .frame(width: 56, height: 56)
              .background(Color(.systemGray6))
              .clipShape(RoundedRectangle(cornerRadius: 12))
          }

          // 제목 입력
          VStack(alignment: .trailing, spacing: 2) {
            TextField("약속 제목", text: Binding(
              get: { store.editedPromise.title },
              set: { store.send(.view(.setTitle($0))) }
            ))
            .focused($focusedField, equals: .title)
            .font(.system(size: 17))
            .padding(16)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("\(store.editedPromise.title.count)/30")
              .font(.system(size: 12))
              .foregroundColor(.secondary)
          }
        }
      }
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 4) {
          Text("설명")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.primary)

          Text("(선택)")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
        }

        VStack(alignment: .trailing, spacing: 4) {
          TextEditor(text: Binding(
            get: { store.editedPromise.description ?? "" },
            set: { store.send(.view(.setDescription($0))) }
          ))
          .focused($focusedField, equals: .description)
          .font(.system(size: 16))
          .frame(minHeight: 80)
          .padding(12)
          .scrollContentBackground(.hidden)
          .background(Color(.systemGray6))
          .clipShape(RoundedRectangle(cornerRadius: 12))

          Text("\((store.editedPromise.description ?? "").count)/500")
            .font(.system(size: 12))
            .foregroundColor(.secondary)
        }
      }
    }

    // MARK: - Start Date Section

    private func startDateSection(proxy: ScrollViewProxy) -> some View {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 4) {
          Text("시작 시간")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.primary)

          Text("*")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.red)
        }

        EditInlineDateTimePicker(
          date: Binding(
            get: { store.editedPromise.startAt },
            set: { store.send(.view(.setStartDate($0))) }
          ),
          scrollProxy: proxy,
          scrollToId: "startDateTime"
        )

        // 시간 경고 (1시간 이내)
        if store.editedPromise.startAt.timeIntervalSinceNow < 3600 &&
           store.editedPromise.startAt.timeIntervalSinceNow > 0 {
          HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
              .font(.system(size: 14))
              .foregroundColor(.orange)

            Text("시작 시간이 1시간 이내입니다.")
              .font(.system(size: 13))
              .foregroundColor(.orange)

            Spacer()
          }
          .padding(12)
          .background(Color.orange.opacity(0.1))
          .clipShape(RoundedRectangle(cornerRadius: 8))
        }
      }
    }

    // MARK: - End Date Section

    private func endDateSection(proxy: ScrollViewProxy) -> some View {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          HStack(spacing: 4) {
            Text("종료 시간")
              .font(.system(size: 15, weight: .semibold))
              .foregroundStyle(.primary)

            Text("(선택)")
              .font(.system(size: 13))
              .foregroundStyle(.secondary)
          }

          Spacer()

          Toggle("", isOn: Binding(
            get: { store.useEndTime },
            set: { _ in store.send(.view(.toggleUseEndTime)) }
          ))
          .labelsHidden()
        }

        if store.useEndTime {
          EditInlineDateTimePicker(
            date: Binding(
              get: { store.editedPromise.endAt ?? store.editedPromise.startAt.addingTimeInterval(7200) },
              set: { store.send(.view(.setEndDate($0))) }
            ),
            minimumDate: store.editedPromise.startAt,
            scrollProxy: proxy,
            scrollToId: "endDateTime"
          )
        }
      }
    }

    // MARK: - Minimum Participants Section

    private var minimumParticipantsSection: some View {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 4) {
          Text("최소 참가 인원")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.primary)

          Text("*")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.red)
        }

        HStack(spacing: 16) {
          Button {
            store.send(.view(.decrementParticipants), animation: .spring(response: 0.3, dampingFraction: 0.7))
          } label: {
            Image(systemName: "minus.circle.fill")
              .font(.system(size: 32))
              .foregroundColor(store.editedPromise.minimumParticipants <= 2 ? Color(.systemGray4) : .blue)
          }
          .buttonRepeatBehavior(.enabled)
          .disabled(store.editedPromise.minimumParticipants <= 2)

          VStack(spacing: 4) {
            Text("\(store.editedPromise.minimumParticipants)명")
              .font(.system(size: 36, weight: .bold))
              .foregroundColor(.primary)
              .contentTransition(.numericText())

            Text("최대 \(store.maxMembers)명")
              .font(.system(size: 13))
              .foregroundColor(.secondary)
          }
          .frame(maxWidth: .infinity)

          Button {
            store.send(.view(.incrementParticipants), animation: .spring(response: 0.3, dampingFraction: 0.7))
          } label: {
            Image(systemName: "plus.circle.fill")
              .font(.system(size: 32))
              .foregroundColor(store.editedPromise.minimumParticipants >= store.maxMembers ? Color(.systemGray4) : .blue)
          }
          .buttonRepeatBehavior(.enabled)
          .disabled(store.editedPromise.minimumParticipants >= store.maxMembers)
        }
        .padding(.vertical, 8)

        // 안내 박스
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 20))
            .foregroundColor(.blue)

          Text("최소 \(store.editedPromise.minimumParticipants)명이 참석하면 약속이 자동으로 확정됩니다")
            .font(.system(size: 14))
            .foregroundColor(.primary)

          Spacer()
        }
        .padding(16)
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
      }
    }
  }
}

// MARK: - Edit Inline DateTime Picker

private struct EditInlineDateTimePicker: View {
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
      HStack(spacing: 16) {
        // 날짜 영역
        Button(action: {
          withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            if expandedSection == .date {
              expandedSection = nil
            } else {
              expandedSection = .date
              scrollAfterDelay()
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
              scrollAfterDelay()
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

      // DatePicker
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

  private func scrollAfterDelay() {
    if let scrollProxy = scrollProxy, let scrollToId = scrollToId {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
        withAnimation {
          scrollProxy.scrollTo(scrollToId, anchor: .top)
        }
      }
    }
  }
}
