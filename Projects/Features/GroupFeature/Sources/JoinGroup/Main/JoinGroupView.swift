import SwiftUI
import ComposableArchitecture
import Shared

extension JoinGroup {
  public struct RootView: View {
    @Bindable private var store: StoreOf<JoinGroup.Feature>
    
    public init(store: StoreOf<JoinGroup.Feature>) {
      self.store = store
    }
    
    public var body: some View {
      Group {
        switch store.step {
        case .enterCode:
          EnterCodeView(store: store)
        case .preview(let group):
          PreviewView(store: store, group: group)
        }
      }
      .auroraBackground()
      .navigationTitle("그룹 참여")
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        store.send(.view(.onAppear))
      }
      .alert(
        "오류",
        isPresented: .constant(store.previewError != nil),
        actions: {
          Button("확인") {
            store.send(.view(.previewErrorAlertDismissed))
          }
        },
        message: {
          if let error = store.previewError {
            Text(error)
          }
        }
      )
      .alert(
        "참여 실패",
        isPresented: .constant(store.joinError != nil),
        actions: {
          Button("확인") {
            store.send(.view(.joinErrorAlertDismissed))
          }
        },
        message: {
          if let error = store.joinError {
            Text(error)
          }
        }
      )
      .alert(
        "그룹 참여 완료",
        isPresented: .constant(store.joinResult != nil),
        actions: {
          Button("확인") {
            store.send(.view(.successAcknowledged))
          }
        },
        message: {
          if let result = store.joinResult {
            Text("\(result.name) 그룹에 참여했습니다!")
          }
        }
      )
    }
  }
}

// MARK: - Enter Code View

private struct EnterCodeView: View {
  @Bindable var store: StoreOf<JoinGroup.Feature>
  @FocusState private var isCodeFieldFocused: Bool
  
  var body: some View {
    VStack(spacing: 0) {
      // Header
      headerSection
        .padding(.top, 32)
        .padding(.horizontal, 24)
      
      // Code Input
      codeInputSection
        .padding(.top, 48)
        .padding(.horizontal, 24)
      
      Spacer()
      
      // Next Button
      nextButton
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }
    .onAppear {
      isCodeFieldFocused = true
    }
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button {
          store.send(.view(.cancelTapped))
        } label: {
          Image(systemName: "xmark")
        }
      }
    }
  }
  
  // MARK: - Header Section
  
  @ViewBuilder
  private var headerSection: some View {
    VStack(spacing: 16) {
      // Icon
      ZStack {
        Circle()
          .fill(
            LinearGradient(
              colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.1)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .frame(width: 80, height: 80)
        
        Image(systemName: "link.circle.fill")
          .font(.system(size: 40))
          .foregroundStyle(
            LinearGradient(
              colors: [.blue, .purple],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
      }
      
      // Title & Description
      VStack(spacing: 8) {
        Text("초대 코드 입력")
          .font(.title2.bold())
        
        Text("6자리 초대 코드를\n입력해주세요")
          .font(.body)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .lineSpacing(4)
      }
    }
  }
  
  // MARK: - Code Input Section
  
  @ViewBuilder
  private var codeInputSection: some View {
    VStack(spacing: 16) {
      // Code Display Boxes
      HStack(spacing: 12) {
        ForEach(0..<6, id: \.self) { index in
          codeCharacterBox(at: index)
        }
      }
      
      // Hidden TextField for actual input
      TextField("", text: .init(
        get: { store.inviteCode },
        set: { store.send(.view(.codeChanged($0))) }
      ))
      .keyboardType(.asciiCapable)
      .autocapitalization(.allCharacters)
      .disableAutocorrection(true)
      .focused($isCodeFieldFocused)
      .opacity(0)
      .frame(height: 0)
    }
    .onTapGesture {
      isCodeFieldFocused = true
    }
  }
  
  // MARK: - Code Character Box
  
  @ViewBuilder
  private func codeCharacterBox(at index: Int) -> some View {
    let character = store.inviteCode.count > index
    ? String(store.inviteCode[store.inviteCode.index(store.inviteCode.startIndex, offsetBy: index)])
    : ""
    
    ZStack {
      RoundedRectangle(cornerRadius: 12)
        .fill(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
      
      RoundedRectangle(cornerRadius: 12)
        .strokeBorder(
          store.inviteCode.count == index && isCodeFieldFocused
          ? LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
          : LinearGradient(
            colors: [Color(.systemGray4)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: store.inviteCode.count == index && isCodeFieldFocused ? 2 : 1
        )
      
      Text(character)
        .font(.system(size: 28, weight: .bold, design: .rounded))
        .foregroundStyle(
          character.isEmpty
          ? AnyShapeStyle(Color.secondary.opacity(0.3))
          : AnyShapeStyle(LinearGradient(
            colors: [.primary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ))
        )
    }
    .frame(width: 48, height: 60)
    .animation(.easeInOut(duration: 0.2), value: store.inviteCode)
    .animation(.easeInOut(duration: 0.2), value: isCodeFieldFocused)
  }
  
  // MARK: - Next Button
  
  @ViewBuilder
  private var nextButton: some View {
    Button {
      store.send(.view(.nextTapped))
    } label: {
      HStack(spacing: 8) {
        if store.isLoadingPreview {
          ProgressView()
            .tint(.white)
        } else {
          Image(systemName: "arrow.right.circle.fill")
            .font(.system(size: 18))
        }
        
        Text(store.isLoadingPreview ? "확인 중..." : "다음")
          .font(.headline)
      }
      .frame(maxWidth: .infinity)
      .frame(height: 56)
      .background(
        LinearGradient(
          colors: store.canProceedToPreview
          ? [.blue, .purple]
          : [Color(.systemGray4)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .foregroundStyle(.white)
      .clipShape(RoundedRectangle(cornerRadius: 16))
      .shadow(
        color: store.canProceedToPreview ? .blue.opacity(0.3) : .clear,
        radius: 12,
        x: 0,
        y: 6
      )
    }
    .disabled(!store.canProceedToPreview)
    .animation(.easeInOut(duration: 0.2), value: store.canProceedToPreview)
    .animation(.easeInOut(duration: 0.2), value: store.isLoadingPreview)
  }
}

// MARK: - Preview View

private struct PreviewView: View {
  @Bindable var store: StoreOf<JoinGroup.Feature>
  let group: GroupModel
  
  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(spacing: 32) {
          Spacer()
            .frame(height: 20)
          
          // Group Info
          groupInfoSection
          
          // Details
          detailsSection
          
          Spacer()
            .frame(height: 20)
        }
        .padding(.horizontal, 24)
      }
      
      // Join Button
      VStack(spacing: 12) {
        joinButton
      }
      .padding(.horizontal, 24)
      .padding(.bottom, 32)
    }
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button {
          store.send(.view(.backTapped))
        } label: {
          HStack(spacing: 4) {
            Image(systemName: "chevron.left")
          }
        }
      }
    }
  }
  
  // MARK: - Group Info Section
  
  @ViewBuilder
  private var groupInfoSection: some View {
    VStack(spacing: 16) {
      // Icon/Emoji
      ZStack {
        Circle()
          .fill(
            LinearGradient(
              colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.1)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .frame(width: 100, height: 100)
        
        Text(group.emoji)
          .font(.system(size: 50))
      }
      
      // Name
      Text(group.name)
        .font(.title.bold())
      
      // Description
      if let description = group.description, !description.isEmpty {
        Text(description)
          .font(.body)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .lineSpacing(4)
      }
    }
  }
  
  // MARK: - Details Section
  
  @ViewBuilder
  private var detailsSection: some View {
    VStack(spacing: 12) {
      detailRow(
        icon: "person.2.fill",
        title: "멤버 수",
        value: "\(group.memberCount)명"
      )
      
      if let maxMembers = group.maxMembers {
        detailRow(
          icon: "person.3.fill",
          title: "최대 인원",
          value: "\(maxMembers)명"
        )
      }
      
      detailRow(
        icon: "calendar.badge.clock",
        title: "진행 중 약속",
        value: "\(group.activePromiseCount)개"
      )
      
      detailRow(
        icon: "link.circle.fill",
        title: "초대 코드",
        value: group.inviteCode
      )
    }
  }
  
  @ViewBuilder
  private func detailRow(icon: String, title: String, value: String) -> some View {
    HStack(spacing: 16) {
      Image(systemName: icon)
        .font(.system(size: 20))
        .foregroundStyle(
          LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .frame(width: 32)
      
      Text(title)
        .font(.body)
        .foregroundStyle(.secondary)
      
      Spacer()
      
      Text(value)
        .font(.body.bold())
        .foregroundStyle(.primary)
    }
    .padding(16)
    .background(Color(.systemGray6))
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }
  
  // MARK: - Join Button
  
  @ViewBuilder
  private var joinButton: some View {
    Button {
      store.send(.view(.joinGroupTapped))
    } label: {
      HStack(spacing: 8) {
        if store.isJoining {
          ProgressView()
            .tint(.white)
        } else {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 18))
        }
        
        Text(store.isJoining ? "참여 중..." : "그룹 참여하기")
          .font(.headline)
      }
      .frame(maxWidth: .infinity)
      .frame(height: 56)
      .background(
        LinearGradient(
          colors: store.canJoin
          ? [.blue, .purple]
          : [Color(.systemGray4)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .foregroundStyle(.white)
      .clipShape(RoundedRectangle(cornerRadius: 16))
      .shadow(
        color: store.canJoin ? .blue.opacity(0.3) : .clear,
        radius: 12,
        x: 0,
        y: 6
      )
    }
    .disabled(!store.canJoin)
    .animation(.easeInOut(duration: 0.2), value: store.canJoin)
    .animation(.easeInOut(duration: 0.2), value: store.isJoining)
  }
}
