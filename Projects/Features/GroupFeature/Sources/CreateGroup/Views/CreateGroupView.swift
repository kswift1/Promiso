import SwiftUI
import PhotosUI
import ComposableArchitecture
import UIKit

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
          
          // Max Members Section
          MaxMembersSection(
            maxMembers: $store.maxMembers
          )
          
          Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
      }
      .onTapGesture {
        dismissKeyboard()
      }
      .navigationTitle("그룹 만들기")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            store.send(.view(.cancelTapped))
          } label: {
            Image(systemName: "xmark")
              .font(.system(size: 16, weight: .semibold))
          }
        }
      }
      .safeAreaInset(edge: .bottom) {
        BottomButton(
          isValid: store.isValid,
          action: { store.send(.view(.createGroupTapped)) }
        )
      }
      .onAppear {
        store.send(.view(.onAppear))
      }
      .background(Color(.systemGray6))
    }
  }
}

private func dismissKeyboard() {
  UIApplication.shared.sendAction(
    #selector(UIResponder.resignFirstResponder),
    to: nil,
    from: nil,
    for: nil
  )
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
      
      TextField("그룹 이름을 입력하세요", text: $groupName)
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

// MARK: - Max Members Section

private struct MaxMembersSection: View {
  @Binding var maxMembers: MaxMembers
  
  var body: some View {
    HStack {
      Text("최대 인원")
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(.primary)
      
      Spacer()
      
      Picker("", selection: $maxMembers) {
        ForEach(MaxMembers.allCases, id: \.self) { option in
          Text(option.displayText).tag(option)
        }
      }
      .pickerStyle(.menu)
      .tint(.blue)
    }
    .padding(12)
    .background(Color(.systemBackground))
    .cornerRadius(8)
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
