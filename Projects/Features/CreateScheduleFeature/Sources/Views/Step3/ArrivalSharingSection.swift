import SwiftUI
import Clients
import ComposableArchitecture
import PromisoShared
import ResourceKit

struct ArrivalSharingSection: View {
  @Bindable var store: StoreOf<CreateSchedule.Feature>
  @State private var customMinutesText = ""
  @FocusState private var isCustomInputFocused: Bool

  private var selectedMinutes: Int? {
    store.schedule.trackingStartMinutesBefore
  }

  private var isEnabled: Bool {
    selectedMinutes != nil
  }

  /// 프리셋 옵션에 해당하는지 (15, 30, 60)
  private var isPresetOption: Bool {
    guard let minutes = selectedMinutes else { return false }
    return [15, 30, 60].contains(minutes)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      // 커스텀 헤더 (제목 + info 버튼 + 토글)
      HStack(spacing: 8) {
        Text(LocalizedStrings.CreateSchedule.liveSharing)
          .font(.system(size: 15, weight: .semibold))
          .foregroundColor(.primary)

        Button {
          store.send(.view(.liveActivityInfoButtonTapped))
        } label: {
          Image(systemName: "info.circle")
            .font(.system(size: 14))
            .foregroundColor(.secondary)
        }
        .popover(
          isPresented: Binding(
            get: { store.showLiveActivityInfo },
            set: { newValue in
              if !newValue {
                store.send(.view(.liveActivityInfoDismissed))
              }
            }
          ),
          arrowEdge: .top
        ) {
          LiveActivityInfoPopover()
        }

        Spacer()

        // 토글 버튼 (오른쪽)
        Toggle("", isOn: Binding(
          get: { isEnabled },
          set: { newValue in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
              if newValue {
                // 켜면 기본값 30분으로 설정
                _ = store.send(.view(.setTrackingStartMinutes(30)))
              } else {
                _ = store.send(.view(.setTrackingStartMinutes(nil)))
              }
            }
          }
        ))
        .labelsHidden()
        .tint(Color.pmindigo.n500)
      }

      // 설명 + 옵션들 (토글 켜졌을 때만)
      if isEnabled {
        VStack(spacing: 12) {
          // 설명
          Text(LocalizedStrings.CreateSchedule.liveSharingDescription)
            .font(.system(size: 13))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)

          // 시간 옵션들
          HStack(spacing: 8) {
            // 15분
            TimeOptionChip(
              title: LocalizedStrings.CreateSchedule.minutes15Before,
              isSelected: selectedMinutes == 15
            ) {
              isCustomInputFocused = false
              customMinutesText = ""
              withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                _ = store.send(.view(.setTrackingStartMinutes(15)))
              }
            }

            // 30분
            TimeOptionChip(
              title: LocalizedStrings.CreateSchedule.minutes30Before,
              isSelected: selectedMinutes == 30
            ) {
              isCustomInputFocused = false
              customMinutesText = ""
              withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                _ = store.send(.view(.setTrackingStartMinutes(30)))
              }
            }

            // 1시간
            TimeOptionChip(
              title: LocalizedStrings.CreateSchedule.hour1Before,
              isSelected: selectedMinutes == 60
            ) {
              isCustomInputFocused = false
              customMinutesText = ""
              withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                _ = store.send(.view(.setTrackingStartMinutes(60)))
              }
            }

            // 직접 입력
            CustomMinuteInput(
              text: $customMinutesText,
              isActive: !isPresetOption && isEnabled,
              isFocused: $isCustomInputFocused
            ) { minutes in
              withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                _ = store.send(.view(.setTrackingStartMinutes(minutes)))
              }
            }
          }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .transition(.opacity.combined(with: .move(edge: .top)))
        .onTapGesture {
          // 다른 곳 탭하면 키보드 내리기
          if isCustomInputFocused {
            isCustomInputFocused = false
          }
        }
      }
    }
    .onAppear {
      // 초기 상태: 켜진 상태로 시작 (30분 기본값)
      if selectedMinutes == nil {
        store.send(.view(.setTrackingStartMinutes(30)))
      }
    }
    .onAppear {
      // UserDefaults에서 본 적 있는지 확인 후 처음이면 팝오버 표시 (딜레이는 Reducer Effect에서 처리)
      store.send(.view(.arrivalSharingSectionAppeared))
    }
    .onChange(of: isCustomInputFocused) { _, isFocused in
      // 키보드 내려갈 때 빈 값이면 30분으로 복귀
      if !isFocused && customMinutesText.isEmpty && !isPresetOption {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
          _ = store.send(.view(.setTrackingStartMinutes(30)))
        }
      }
    }
  }
}

// MARK: - Time Option Chip

private struct TimeOptionChip: View {
  let title: String
  let isSelected: Bool
  let action: () -> Void

  @State private var isPressed = false

  var body: some View {
    Button {
      action()
    } label: {
      Text(title)
        .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
        .foregroundColor(isSelected ? .white : .primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
          Group {
            if isSelected {
              Color.pmindigo.n500
            } else {
              Color(.systemGray5)
            }
          }
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
          RoundedRectangle(cornerRadius: 10)
            .stroke(isSelected ? Color.pmindigo.n300 : Color.clear, lineWidth: 1)
        )
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
    }
    .buttonStyle(.plain)
    .simultaneousGesture(
      DragGesture(minimumDistance: 0)
        .onChanged { _ in isPressed = true }
        .onEnded { _ in isPressed = false }
    )
    .sensoryFeedback(.selection, trigger: isSelected)
  }
}

// MARK: - Custom Minute Input

private struct CustomMinuteInput: View {
  @Binding var text: String
  let isActive: Bool
  var isFocused: FocusState<Bool>.Binding
  let onSubmit: (Int) -> Void

  @State private var isPressed = false

  var body: some View {
    HStack(spacing: 2) {
      TextField("", text: $text, prompt: Text(LocalizedStrings.CreateSchedule.customInput).foregroundColor(isActive ? .white.opacity(0.6) : .secondary))
        .font(.system(size: 13, weight: isActive ? .semibold : .medium))
        .foregroundColor(isActive ? .white : .primary)
        .multilineTextAlignment(.center)
        .keyboardType(.numberPad)
        .focused(isFocused)
        .frame(width: 32)
        .onChange(of: text) { _, newValue in
          // 숫자만 허용
          let filtered = String(newValue.filter { $0.isNumber }.prefix(AppConstants.LiveActivity.maxCustomMinutesDigits))
          if filtered != newValue {
            text = filtered
          }
          // 값이 있으면 즉시 적용
          if let minutes = Int(filtered), minutes > 0 {
            onSubmit(minutes)
          }
        }

      Text(LocalizedStrings.CreateSchedule.minutesBefore)
        .font(.system(size: 13, weight: isActive ? .semibold : .medium))
        .foregroundColor(isActive ? .white : .primary)
        .fixedSize()
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 10)
    .background(
      Group {
        if isActive {
          Color.pmindigo.n500
        } else {
          Color(.systemGray5)
        }
      }
    )
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(isActive ? Color.pmindigo.n300 : Color.clear, lineWidth: 1)
    )
    .scaleEffect(isPressed ? 0.95 : 1.0)
    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
    .onTapGesture {
      withAnimation(.spring(response: 0.2)) {
        isPressed = true
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        isPressed = false
      }
      isFocused.wrappedValue = true
    }
    .sensoryFeedback(.selection, trigger: isActive)
  }
}

