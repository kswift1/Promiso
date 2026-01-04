import SwiftUI
import ComposableArchitecture
import Shared
import Clients
import Nuke

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
        case .preview(let preview):
          PreviewView(
            store: store,
            group: preview.group,
            members: preview.members
          )
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
      // Code Display Boxes with overlay TextField
      HStack(spacing: 12) {
        ForEach(0..<6, id: \.self) { index in
          codeCharacterBox(at: index)
        }
      }
      .overlay(
        // Transparent TextField overlay for paste support
        TextField("", text: .init(
          get: { store.inviteCode },
          set: { store.send(.view(.codeChanged($0))) }
        ))
        .keyboardType(.asciiCapable)
        .autocapitalization(.allCharacters)
        .disableAutocorrection(true)
        .textContentType(.oneTimeCode) // OTP 자동완성 및 복사-붙여넣기 지원
        .focused($isCodeFieldFocused)
        .foregroundColor(.clear) // 텍스트 색상 투명
        .accentColor(.clear) // 커서 색상 투명
        .background(Color.clear)
        .onChange(of: store.inviteCode) { oldValue, newValue in
          // 6자리가 완성되면 자동으로 다음 단계로
          if newValue.count == 6 && store.canProceedToPreview {
            // 키보드 내리기
            isCodeFieldFocused = false
            // 약간의 딜레이 후 다음 단계로 (UX 향상)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
              store.send(.view(.nextTapped))
            }
          }
        }
      )
    }
    .onTapGesture {
      isCodeFieldFocused = true
    }
    .contextMenu {
      // 복사-붙여넣기 메뉴
      if UIPasteboard.general.hasStrings {
        Button {
          if let pasteText = UIPasteboard.general.string {
            store.send(.view(.codeChanged(pasteText)))
            isCodeFieldFocused = true
          }
        } label: {
          Label("붙여넣기", systemImage: "doc.on.clipboard")
        }
      }

      if !store.inviteCode.isEmpty {
        Button {
          UIPasteboard.general.string = store.inviteCode
        } label: {
          Label("복사", systemImage: "doc.on.doc")
        }
      }
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
  let members: [GroupMemberPreview]
  
  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(spacing: 32) {
          Spacer()
            .frame(height: 20)
          
          // Group Info
          cardContainer {
            groupInfoSection
          }
          
          // Member Preview
          if members.isEmpty == false {
            cardContainer {
              memberPreviewSection
            }
          }

          // Details
          cardContainer {
            detailsSection
          }
          
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
      // Group Photo or Emoji
      GroupImageView(photo: group.photo, emoji: group.emoji)

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

  // MARK: - Member Preview Section

  @ViewBuilder
  private var memberPreviewSection: some View {
    VStack(spacing: 12) {
      HStack {
        Text("멤버")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.secondary)

        Spacer()

        Text("\(members.count)명")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.secondary)
      }

      GroupMemberStackView(members: members)

      Text(memberNamesText)
        .font(.footnote)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
  }

  private var memberNamesText: String {
    let displayNames = members.prefix(3).map(\.name)
    let baseText = displayNames.joined(separator: " · ")
    let overflow = max(members.count - displayNames.count, 0)
    if overflow > 0 {
      return "\(baseText) · +\(overflow)"
    }
    return baseText
  }
  
  // MARK: - Details Section
  
  @ViewBuilder
  private var detailsSection: some View {
    VStack(spacing: 12) {
      detailRow(
        icon: "person.2.fill",
        title: "현재 인원",
        value: "\(group.memberCount)명"
      )

      if let maxMembers = group.maxMembers {
        detailRow(
          icon: "person.3.fill",
          title: "최대 인원",
          value: "\(maxMembers)명"
        )
      }
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

  private func cardContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    content()
      .padding(16)
      .frame(maxWidth: .infinity)
      .background(Color(.systemBackground))
      .clipShape(RoundedRectangle(cornerRadius: 16))
      .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
  }
}

private struct GroupMemberStackView: View {
  let members: [GroupMemberPreview]

  private var displayMembers: [GroupMemberPreview] {
    Array(members.prefix(5))
  }

  private var overflowCount: Int {
    max(members.count - displayMembers.count, 0)
  }

  var body: some View {
    HStack(spacing: -12) {
      ForEach(displayMembers) { member in
        MemberAvatarView(member: member)
          .zIndex(Double(displayMembers.count) - Double(displayMembers.firstIndex(where: { $0.id == member.id }) ?? 0))
      }

      if overflowCount > 0 {
        OverflowAvatarView(count: overflowCount)
      }
    }
    .padding(.vertical, 4)
  }
}

private struct MemberAvatarView: View {
  let member: GroupMemberPreview
  @State private var loadedImage: UIImage?
  @State private var isLoading = false

  var body: some View {
    ZStack {
      Circle()
        .fill(Color(.systemGray5))
        .frame(width: 44, height: 44)

      if let loadedImage {
        Image(uiImage: loadedImage)
          .resizable()
          .scaledToFill()
          .frame(width: 44, height: 44)
          .clipShape(Circle())
      } else if isLoading {
        ProgressView()
          .tint(.secondary)
      } else {
        Text(initials)
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(.secondary)
      }
    }
    .overlay(
      Circle()
        .stroke(Color(.systemBackground), lineWidth: 2)
    )
    .task {
      await loadImage()
    }
  }

  private var initials: String {
    String(member.name.prefix(1))
  }

  private func loadImage() async {
    guard let profileImage = member.profileImage else { return }
    isLoading = true
    defer { isLoading = false }

    do {
      guard let url = try await profileImage.toURL() else { return }
      let request = ImageRequest(url: url)
      loadedImage = try await ImagePipeline.shared.image(for: request)
    } catch {
      loadedImage = nil
    }
  }
}

private struct OverflowAvatarView: View {
  let count: Int

  var body: some View {
    ZStack {
      Circle()
        .fill(Color(.systemGray4))
        .frame(width: 44, height: 44)

      Text("+\(count)")
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(.secondary)
    }
    .overlay(
      Circle()
        .stroke(Color(.systemBackground), lineWidth: 2)
    )
  }
}

// MARK: - Group Image View

private struct GroupImageView: View {
  let photo: RemoteImage?
  let emoji: String
  @State private var loadedImage: UIImage?
  @State private var isLoading = false

  var body: some View {
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

      if let uiImage = loadedImage {
        // 이미지 로딩 완료
        Image(uiImage: uiImage)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: 100, height: 100)
          .clipShape(Circle())
      } else if isLoading {
        // 로딩 중
        ProgressView()
      } else {
        // 이미지 없음 또는 로딩 전
        Text(emoji)
          .font(.system(size: 50))
      }
    }
    .task {
      await loadImage()
    }
  }

  private func loadImage() async {
    guard let photo = photo else { return }

    isLoading = true
    defer { isLoading = false }

    do {
      // RemoteImage를 URL로 변환
      guard let url = try await photo.toURL() else { return }

      // Nuke ImagePipeline을 사용하여 이미지 로딩
      let request = ImageRequest(url: url)
      loadedImage = try await ImagePipeline.shared.image(for: request)
    } catch {
      print("Failed to load image: \(error)")
      // 에러 발생 시 이모지 표시 (loadedImage가 nil이므로 자동으로 이모지 표시됨)
    }
  }
}
