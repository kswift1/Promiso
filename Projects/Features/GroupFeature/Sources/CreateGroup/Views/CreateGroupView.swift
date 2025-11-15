import SwiftUI
import PhotosUI
import ComposableArchitecture

extension CreateGroup {
  public struct RootView: View {
    @Bindable private var store: StoreOf<CreateGroup.Feature>

    public init(store: StoreOf<CreateGroup.Feature>) {
      self.store = store
    }

    public var body: some View {
        ScrollView {
          VStack(spacing: 24) {
            // Photo Upload Section
            PhotoUploadSection(
              photoData: store.photoData,
              selectedPhoto: $store.selectedPhoto.sending(\.view.photoSelected)
            )

            // Group Name Section
            GroupNameSection(
              groupName: $store.groupName,
              characterCount: store.characterCount
            )

            // Theme Color Section
            ThemeColorSection(
              selectedColor: $store.themeColor
            )

            // Description Section
            GroupDescriptionSection(
              description: $store.description,
              characterCount: store.descriptionCount
            )

            // Advanced Settings Section
            AdvancedSettingsSection(
              isExpanded: $store.isAdvancedSettingsExpanded,
              maxMembers: $store.maxMembers,
              requireApproval: $store.requireApproval,
              defaultMinParticipants: $store.defaultMinParticipants,
              onToggle: { store.send(.view(.toggleAdvancedSettings)) }
            )

            // Preview Card
            PreviewCard(
              photoData: store.photoData,
              groupName: store.groupName,
              themeColor: store.themeColor,
              description: store.description
            )
          }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .background(Color(.systemGray6))
        .navigationTitle("그룹 만들기")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
          BottomButton(
            isValid: store.isValid,
            action: { store.send(.view(.createGroupTapped)) }
          )
        }
        .onAppear {
          store.send(.view(.onAppear))
        }
      }
    }
  }
}

// MARK: - Photo Upload Section

private struct PhotoUploadSection: View {
  let photoData: Data?
  @Binding var selectedPhoto: PhotosPickerItem?

  var body: some View {
    VStack(spacing: 12) {
      Text("그룹 사진")
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)

      PhotosPickerButton(
        photoData: photoData,
        selectedPhoto: $selectedPhoto
      )
    }
  }
}

private struct PhotosPickerButton: View {
  let photoData: Data?
  @Binding var selectedPhoto: PhotosPickerItem?

  var body: some View {
    PhotosPicker(selection: $selectedPhoto, matching: .images) {
      ZStack {
        if let photoData, let uiImage = UIImage(data: photoData) {
          Image(uiImage: uiImage)
            .resizable()
            .scaledToFill()
            .frame(width: 120, height: 120)
            .clipShape(Circle())
        } else {
          Circle()
            .fill(Color(.systemGray5))
            .frame(width: 120, height: 120)
            .overlay {
              VStack(spacing: 8) {
                Image(systemName: "camera.fill")
                  .font(.system(size: 28))
                  .foregroundColor(.secondary)
                Text("사진 추가")
                  .font(.system(size: 13))
                  .foregroundColor(.secondary)
              }
            }
        }
      }
    }
  }
}

// MARK: - Group Name Section

private struct GroupNameSection: View {
  @Binding var groupName: String
  let characterCount: Int

  var body: some View {
    VStack(spacing: 12) {
      HStack {
        Text("그룹 이름")
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.primary)

        Spacer()

        Text("\(characterCount)/30")
          .font(.system(size: 13))
          .foregroundColor(characterCount >= 2 ? .secondary : .red)
      }

      TextField("예: 대학 친구들, 개발팀, 우리 가족", text: $groupName)
        .textFieldStyle(.plain)
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .onChange(of: groupName) { _, newValue in
          if newValue.count > 30 {
            groupName = String(newValue.prefix(30))
          }
        }

      if characterCount > 0 && characterCount < 2 {
        Text("최소 2자 이상 입력해주세요")
          .font(.system(size: 12))
          .foregroundColor(.red)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }
}

// MARK: - Theme Color Section

private struct ThemeColorSection: View {
  @Binding var selectedColor: ThemeColor

  var body: some View {
    VStack(spacing: 12) {
      Text("테마 색상")
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)

      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
        ForEach(ThemeColor.allCases, id: \.self) { color in
          ColorButton(
            color: color,
            isSelected: selectedColor == color,
            action: { selectedColor = color }
          )
        }
      }
    }
  }
}

private struct ColorButton: View {
  let color: ThemeColor
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 6) {
        ZStack {
          RoundedRectangle(cornerRadius: 8)
            .fill(color.color)
            .frame(height: 60)

          if isSelected {
            Image(systemName: "checkmark")
              .font(.system(size: 20, weight: .bold))
              .foregroundColor(.white)
          }
        }

        Text(color.rawValue)
          .font(.system(size: 12))
          .foregroundColor(.primary)
      }
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Description Section

private struct GroupDescriptionSection: View {
  @Binding var description: String
  let characterCount: Int

  var body: some View {
    VStack(spacing: 12) {
      HStack {
        Text("그룹 설명 (선택)")
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.primary)

        Spacer()

        Text("\(characterCount)/200")
          .font(.system(size: 13))
          .foregroundColor(.secondary)
      }

      TextEditor(text: $description)
        .frame(height: 100)
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
          Group {
            if description.isEmpty {
              Text("그룹에 대한 간단한 설명을 입력하세요")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .allowsHitTesting(false)
            }
          }
        )
        .onChange(of: description) { _, newValue in
          if newValue.count > 200 {
            description = String(newValue.prefix(200))
          }
        }
    }
  }
}

// MARK: - Advanced Settings Section

private struct AdvancedSettingsSection: View {
  @Binding var isExpanded: Bool
  @Binding var maxMembers: MaxMembers
  @Binding var requireApproval: Bool
  @Binding var defaultMinParticipants: Int
  let onToggle: () -> Void

  var body: some View {
    VStack(spacing: 12) {
      Button(action: onToggle) {
        HStack {
          Text("고급 설정")
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.primary)

          Spacer()

          Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.system(size: 14))
            .foregroundColor(.secondary)
        }
      }
      .buttonStyle(.plain)

      if isExpanded {
        VStack(spacing: 16) {
          // Max Members
          HStack {
            Text("최대 인원")
              .font(.system(size: 14))
              .foregroundColor(.primary)

            Spacer()

            Menu {
              ForEach(MaxMembers.allCases, id: \.self) { option in
                Button(option.displayText) {
                  maxMembers = option
                }
              }
            } label: {
              HStack(spacing: 4) {
                Text(maxMembers.displayText)
                  .font(.system(size: 14))
                  .foregroundColor(.primary)
                Image(systemName: "chevron.down")
                  .font(.system(size: 12))
                  .foregroundColor(.secondary)
              }
              .padding(.horizontal, 12)
              .padding(.vertical, 8)
              .background(Color(.systemGray6))
              .cornerRadius(6)
            }
          }

          // Require Approval
          HStack {
            HStack(spacing: 6) {
              Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 14))
                .foregroundColor(.blue)
              Text("초대 승인 필요")
                .font(.system(size: 14))
                .foregroundColor(.primary)
            }

            Spacer()

            Toggle("", isOn: $requireApproval)
              .labelsHidden()
          }

          // Default Min Participants
          HStack {
            Text("기본 최소 참가 인원")
              .font(.system(size: 14))
              .foregroundColor(.primary)

            Spacer()

            Menu {
              ForEach(2...5, id: \.self) { number in
                Button("\(number)명") {
                  defaultMinParticipants = number
                }
              }
            } label: {
              HStack(spacing: 4) {
                Text("\(defaultMinParticipants)명")
                  .font(.system(size: 14))
                  .foregroundColor(.primary)
                Image(systemName: "chevron.down")
                  .font(.system(size: 12))
                  .foregroundColor(.secondary)
              }
              .padding(.horizontal, 12)
              .padding(.vertical, 8)
              .background(Color(.systemGray6))
              .cornerRadius(6)
            }
          }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(8)
      }
    }
  }
}

// MARK: - Preview Card

private struct PreviewCard: View {
  let photoData: Data?
  let groupName: String
  let themeColor: ThemeColor
  let description: String

  var body: some View {
    VStack(spacing: 12) {
      Text("미리보기")
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)

      VStack(spacing: 0) {
        // Header with photo/color
        ZStack {
          themeColor.color
            .frame(height: 100)

          if let photoData, let uiImage = UIImage(data: photoData) {
            Image(uiImage: uiImage)
              .resizable()
              .scaledToFill()
              .frame(height: 100)
              .clipped()
          }
        }

        // Content
        VStack(alignment: .leading, spacing: 12) {
          HStack(spacing: 12) {
            Circle()
              .fill(photoData == nil ? themeColor.color : Color.clear)
              .frame(width: 60, height: 60)
              .overlay {
                if let photoData, let uiImage = UIImage(data: photoData) {
                  Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                } else {
                  Image(systemName: "person.2.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                }
              }
              .offset(y: -30)

            VStack(alignment: .leading, spacing: 4) {
              Text(groupName.isEmpty ? "그룹 이름" : groupName)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)

              Text("1명")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            }
            .padding(.top, 8)

            Spacer()
          }
          .padding(.horizontal, 16)

          if !description.isEmpty {
            Text(description)
              .font(.system(size: 14))
              .foregroundColor(.secondary)
              .lineLimit(3)
              .padding(.horizontal, 16)
              .padding(.bottom, 16)
          }
        }
        .padding(.top, -20)
        .background(Color(.systemBackground))
      }
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
  }
}

// MARK: - Bottom Button

private struct BottomButton: View {
  let isValid: Bool
  let action: () -> Void

  var body: some View {
    VStack(spacing: 8) {
      Button(action: action) {
        Text(isValid ? "그룹 만들기" : "그룹 이름을 입력하세요")
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.white)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
          .background(isValid ? Color.blue : Color(.systemGray4))
          .cornerRadius(12)
      }
      .disabled(!isValid)

      Text("그룹을 만들면 자동으로 관리자가 됩니다")
        .font(.system(size: 12))
        .foregroundColor(.secondary)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 16)
    .background(Color(.systemBackground))
    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: -2)
  }
}

// MARK: - Preview

#Preview {
  let store = Store(initialState: CreateGroup.Feature.State()) {
    CreateGroup.Feature()
  }

  return CreateGroup.RootView(store: store)
}
