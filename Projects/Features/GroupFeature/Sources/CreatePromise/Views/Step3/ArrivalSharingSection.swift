import SwiftUI
import Clients
import ComposableArchitecture
import PromisoShared
import ResourceKit

struct ArrivalSharingSection: View {
  @Bindable var store: StoreOf<CreatePromise.Feature>
  @State private var customMinutesText = ""
  @FocusState private var isCustomInputFocused: Bool

  private var selectedMinutes: Int? {
    store.promise.trackingStartMinutesBefore
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
        Text("실시간 공유")
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
          Text("약속 시간 전부터 참가자들의 도착 상황을 실시간으로 공유해요")
            .font(.system(size: 13))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)

          // 시간 옵션들
          HStack(spacing: 8) {
            // 15분
            TimeOptionChip(
              title: "15분 전",
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
              title: "30분 전",
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
              title: "1시간 전",
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
    .task {
      try? await Task.sleep(for: .seconds(1))
      // UserDefaults에서 본 적 있는지 확인 후 처음이면 팝오버 표시
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
      TextField("", text: $text, prompt: Text("직접").foregroundColor(isActive ? .white.opacity(0.6) : .secondary))
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

      Text("분 전")
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

// MARK: - LiveActivity Info Popover

private struct LiveActivityInfoPopover: View {
  @Environment(\.colorScheme) private var colorScheme
  @State private var animationProgress: Double = 0

  var body: some View {
    VStack(spacing: 16) {
      // 헤더
      VStack(spacing: 4) {
        Text("실시간 공유란?")
          .font(.system(size: 17, weight: .bold))
          .foregroundColor(.primary)

        Text("잠금화면과 다이나믹 아일랜드에서\n친구들의 도착 상황을 확인할 수 있어요")
          .font(.system(size: 13))
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
      }

      // LiveActivity 미리보기
      VStack(spacing: 12) {
        // Dynamic Island 스타일 미리보기
        dynamicIslandCompactPreview

        // 잠금화면 스타일 미리보기
        lockScreenPreview
      }

      // 안내 문구
      HStack(spacing: 6) {
        Image(systemName: "sparkles")
          .font(.system(size: 12))
          .foregroundColor(.purple)
        Text("약속 시간 전에 자동으로 시작돼요")
          .font(.system(size: 12))
          .foregroundColor(.secondary)
      }
      .padding(.top, 4)
    }
    .padding(20)
    .frame(width: 300)
    .presentationCompactAdaptation(.popover)
    .onAppear {
      // 팝오버 열릴 때 진행률 애니메이션 시작
      withAnimation(.easeOut(duration: 1.2).delay(0.3)) {
        animationProgress = 1.0
      }
    }
  }

  // MARK: - Dynamic Island Compact Preview

  private var dynamicIslandCompactPreview: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("다이나믹 아일랜드")
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(.pmtext.secondary)

      // Dynamic Island Compact 모양 (실제 구현과 동일)
      HStack(spacing: 0) {
        // Leading: 뱃지 스타일
        Text("🍕 피자 약속")
          .font(.system(size: 11, weight: .semibold))
          .foregroundColor(.white)
          .lineLimit(1)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(Color.purple.opacity(0.3))
          .clipShape(Capsule())

        Spacer()

        // Trailing: PM 시간
        HStack(spacing: 2) {
          Text("PM")
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundColor(.white.opacity(0.6))
          Text("6:00")
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
        }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .background(Color.black, in: Capsule())
      
      HStack {
        Spacer()
        
        Text("* iPhone 14 Pro 이상부터 가능해요")
          .font(.system(size: 9, weight: .regular))
          .foregroundColor(.pmtext.secondary)
      }
    }
  }

  // MARK: - Lock Screen Preview

  private var lockScreenPreview: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("잠금화면")
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(.secondary)

      VStack(spacing: 8) {
        // 헤더 (실제 구현과 동일)
        HStack {
          // 왼쪽: 약속 정보
          VStack(alignment: .leading, spacing: 4) {
            Text("🍕 피자 약속")
              .font(.system(size: 13, weight: .bold))
              .foregroundColor(.white)
              .lineLimit(1)

            HStack(spacing: 3) {
              Text("📍")
                .font(.system(size: 9))
              Text("강남역 11번 출구")
                .font(.system(size: 10))
            }
            .foregroundColor(.white.opacity(0.6))
          }

          Spacer()

          // 오른쪽: 약속 시간
          VStack(alignment: .trailing, spacing: 1) {
            Text("약속 시간")
              .font(.system(size: 9))
              .foregroundColor(.white.opacity(0.6))

            HStack(alignment: .firstTextBaseline, spacing: 3) {
              Text("PM")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))

              Text("6:00")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            }
          }
        }

        // 레이싱 트랙 (실제 구현과 유사)
        racingTrackPreview

        // ETA 버튼들 (실제 구현과 동일)
        etaButtonsPreview
      }
      .padding(10)
      .background(Color.black, in: RoundedRectangle(cornerRadius: 16))
    }
  }

  // MARK: - Racing Track Preview

  private var racingTrackPreview: some View {
    GeometryReader { geo in
      let width = geo.size.width
      let padding: CGFloat = 16
      let myProgress = 0.65 * animationProgress  // "나"만 애니메이션

      ZStack {
        // 트랙 배경 (줄무늬)
        Capsule()
          .fill(Color.white.opacity(0.06))
          .overlay {
            HStack(spacing: 0) {
              ForEach(0..<20, id: \.self) { i in
                Rectangle()
                  .fill(i % 2 == 0 ? Color.white.opacity(0.04) : Color.black.opacity(0.2))
                  .frame(width: 12)
              }
            }
            .clipShape(Capsule())
          }
          .overlay {
            Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5)
          }

        // 점선 (고정)
        Path { path in
          path.move(to: CGPoint(x: padding, y: geo.size.height / 2))
          path.addLine(to: CGPoint(x: width - padding, y: geo.size.height / 2))
        }
        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 3]))
        .foregroundColor(.white.opacity(0.15))

        // 진행률 트랙 ("나"만 애니메이션)
        Capsule()
          .fill(
            LinearGradient(
              colors: [Color.indigo, Color.purple],
              startPoint: .leading,
              endPoint: .trailing
            )
          )
          .frame(width: max((width - padding * 2) * myProgress, 4), height: 3)
          .position(x: padding + max((width - padding * 2) * myProgress, 4) / 2, y: geo.size.height / 2)

        // 출발 마커
        Circle()
          .fill(Color.white.opacity(0.25))
          .frame(width: 5, height: 5)
          .position(x: padding, y: geo.size.height / 2)

        // 도착 깃발
        Text("🏁")
          .font(.system(size: 14))
          .position(x: width - padding + 2, y: geo.size.height / 2)

        // 참가자 마커들
        // 민수, 재윤은 고정 / "나"만 애니메이션
        participantMarker(name: "민수", emoji: "🐻", progress: 0.35, color: .orange, width: width, padding: padding, centerY: geo.size.height / 2, eta: "15분")
        participantMarker(name: "재윤", emoji: "🐰", progress: 0.85, color: .green, width: width, padding: padding, centerY: geo.size.height / 2, eta: nil)
        participantMarker(name: "나", emoji: "😀", progress: myProgress, color: .indigo, width: width, padding: padding, centerY: geo.size.height / 2, eta: "5분")
      }
    }
    .frame(height: 36)
  }

  private func participantMarker(name: String, emoji: String, progress: Double, color: Color, width: CGFloat, padding: CGFloat, centerY: CGFloat, eta: String?) -> some View {
    let xPos = padding + ((width - padding * 2) * progress)
    let isArrived = eta == nil

    return ZStack {
      // 마커
      Circle()
        .fill(color.gradient)
        .frame(width: 22, height: 22)
        .overlay {
          Text(emoji)
            .font(.system(size: 11))
        }
        .overlay(
          Circle().stroke(color, lineWidth: 1.5)
        )
        .shadow(color: color.opacity(0.4), radius: 3, y: 1)

      // 이름 라벨
      Text(name)
        .font(.system(size: 7, weight: .bold))
        .foregroundColor(.white.opacity(0.9))
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(
          Capsule().fill(isArrived ? color : Color.black.opacity(0.4))
        )
        .offset(y: -15)

      // ETA 뱃지
      if let eta = eta {
        Text(eta)
          .font(.system(size: 6, weight: .bold))
          .foregroundColor(.white)
          .padding(.horizontal, 3)
          .padding(.vertical, 1)
          .background(Capsule().fill(color))
          .offset(x: 8, y: 8)
      } else {
        // 도착 체크
        Text("✓")
          .font(.system(size: 6, weight: .bold))
          .foregroundColor(.white)
          .padding(.horizontal, 3)
          .padding(.vertical, 1)
          .background(Capsule().fill(Color.green))
          .offset(x: 8, y: 8)
      }
    }
    .position(x: xPos, y: centerY)
  }

  // MARK: - ETA Buttons Preview

  private var etaButtonsPreview: some View {
    HStack(spacing: 4) {
      // 라벨
      VStack(alignment: .leading, spacing: 1) {
        Text("도착까지")
          .font(.system(size: 8, weight: .medium))
          .foregroundColor(.white.opacity(0.4))
      }
      .frame(width: 32)

      // 버튼들
      HStack(spacing: 4) {
        etaButton(title: "완료", isSelected: false)
        etaButton(title: "5분", isSelected: true)
        etaButton(title: "10분", isSelected: false)
        etaButton(title: "직접", isSelected: false)
      }
      .padding(3)
      .background(Color.black.opacity(0.3))
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
      )
    }
  }

  private func etaButton(title: String, isSelected: Bool) -> some View {
    Text(title)
      .font(.system(size: 9, weight: isSelected ? .bold : .medium))
      .foregroundColor(isSelected ? .white : .white.opacity(0.5))
      .frame(maxWidth: .infinity)
      .padding(.vertical, 5)
      .background(
        Group {
          if isSelected {
            LinearGradient(
              colors: [Color.indigo, Color.purple],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          } else {
            Color.white.opacity(0.08)
          }
        }
      )
      .clipShape(RoundedRectangle(cornerRadius: 5))
  }
}

// MARK: - Sharing Option Button

