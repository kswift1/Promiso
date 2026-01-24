import SwiftUI
import Clients
import ComposableArchitecture
import ResourceKit

struct MinimumParticipantsSection: View {
  let store: StoreOf<CreatePromise.Feature>
  var scrollProxy: ScrollViewProxy? = nil
  @State private var isMinusPressed = false
  @State private var isPlusPressed = false

  // 현재 최소 참가 인원
  private var currentMinimum: Int {
    store.promise.minimumParticipants
  }

  // 2명 고정 여부
  private var isFixedAtTwo: Bool {
    store.promise.group?.memberIds.count == 2
  }

  // 최대 인원 (기본값 2명)
  private var maxParticipants: Int {
    store.promise.group?.memberIds.count ?? 2
  }
  
  var body: some View {
    SectionPlaceHolder(placeHolderTitle: "최소 참가 인원") {
      VStack(alignment: .leading, spacing: 12) {
        if isFixedAtTwo {
          // 2명 고정 케이스
          fixedParticipantsView
        } else {
          // 선택 가능한 케이스
          adjustableParticipantsView
          
          // 안내 박스
          infoBox
          
          // 경고 메시지 (최대 인원과 같을 때)
          if currentMinimum == maxParticipants {
            warningMessage
          }
        }
      }
    }
  }
  
  // MARK: - 2명 고정 UI
  private var fixedParticipantsView: some View {
    VStack(spacing: 16) {
      VStack(spacing: 8) {
        Text("2명")
          .font(.system(size: 36, weight: .bold))
          .foregroundColor(.primary)
        
        Text("최대 2명")
          .font(.system(size: 13))
          .foregroundColor(.secondary)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 8)
      
      // 고정 안내
      HStack(spacing: 12) {
        Image(systemName: "lock.fill")
          .font(.system(size: 16))
          .foregroundColor(.secondary)
        
        Text("그룹이 2명이므로 최소 참가 인원이 2명으로 고정됩니다")
          .font(.system(size: 14))
          .foregroundColor(.secondary)
      }
      .padding(16)
      .background(Color(.systemGray6))
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
  }
  
  // MARK: - 조정 가능한 UI
  private var adjustableParticipantsView: some View {
    HStack(spacing: 16) {
      Button(
        action: {
          store.send(
            .view(.decrementParticipants),
            animation: .spring(response: 0.3, dampingFraction: 0.7)
          )
          scrollToMinimumParticipants()
        }) {
          Image(systemName: "minus.circle.fill")
            .font(.system(size: 32))
            .foregroundColor(currentMinimum <= 2 ? Color(.systemGray4) : Color.pmindigo.n500)
            .scaleEffect(isMinusPressed ? 0.85 : 1.0)
        }
        .buttonRepeatBehavior(.enabled)
        .animation(.spring(response: 0.15, dampingFraction: 0.5), value: isMinusPressed)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: currentMinimum)
        .simultaneousGesture(
          DragGesture(minimumDistance: 0)
            .onChanged { _ in if currentMinimum > 2 { isMinusPressed = true } }
            .onEnded { _ in isMinusPressed = false }
        )
        .disabled(currentMinimum <= 2)

      VStack(spacing: 4) {
        Text("\(currentMinimum)명")
          .font(.system(size: 36, weight: .bold))
          .foregroundColor(.primary)
          .contentTransition(.numericText())

        Text("최대 \(maxParticipants)명")
          .font(.system(size: 13))
          .foregroundColor(.secondary)
      }
      .frame(maxWidth: .infinity)

      Button(
        action: {
          store.send(
            .view(.incrementParticipants),
            animation: .spring(response: 0.3, dampingFraction: 0.7)
          )
          scrollToMinimumParticipants()
        }) {
          Image(systemName: "plus.circle.fill")
            .font(.system(size: 32))
            .foregroundColor(currentMinimum >= maxParticipants ? Color(.systemGray4) : Color.pmindigo.n500)
            .scaleEffect(isPlusPressed ? 0.85 : 1.0)
        }
        .buttonRepeatBehavior(.enabled)
        .animation(.spring(response: 0.15, dampingFraction: 0.5), value: isPlusPressed)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: currentMinimum)
        .simultaneousGesture(
          DragGesture(minimumDistance: 0)
            .onChanged { _ in if currentMinimum < maxParticipants { isPlusPressed = true } }
            .onEnded { _ in isPlusPressed = false }
        )
        .disabled(currentMinimum >= maxParticipants)
    }
    .padding(.vertical, 8)
  }
  
  // MARK: - 스크롤 헬퍼
  private func scrollToMinimumParticipants() {
    if let scrollProxy = scrollProxy {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        withAnimation {
          scrollProxy.scrollTo("minimumParticipants", anchor: .center)
        }
      }
    }
  }
  
  // MARK: - 안내 박스
  private var infoBox: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 20))
        .foregroundColor(Color.pmindigo.n500)

      Text("최소 \(currentMinimum)명이 참석하면 약속이 자동으로 확정됩니다")
        .font(.system(size: 14))
        .foregroundColor(.primary)
        .fixedSize(horizontal: false, vertical: true)

      Spacer(minLength: 0)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.pmindigo.n50)
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }
  
  // MARK: - 경고 메시지
  private var warningMessage: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 14))
        .foregroundColor(Color.pmwarning.n600)

      Text("최소 참가 인원이 그룹 멤버 수와 같습니다. 한 명이라도 불참하면 약속이 취소됩니다.")
        .font(.system(size: 13))
        .foregroundColor(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      Spacer(minLength: 0)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.pmwarning.n50)
    .clipShape(RoundedRectangle(cornerRadius: 10))
  }
}
