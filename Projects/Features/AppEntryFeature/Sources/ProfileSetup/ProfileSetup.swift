//
//  ProfileSetup.swift
//  AppEntryFeature
//
//  Created by 김성원 on 12/9/25.
//

import Foundation
import SwiftUI
import PhotosUI

enum ProfileImageType: Equatable {
  case url(URL)
  case data(Data?)
  case none
}

extension AppEntry {
  @Reducer
  public struct ProfileSetup {
    @ObservableState
    public struct State: Equatable {
      var selectedPhoto: PhotosPickerItem?
      var profileImage: ProfileImageType
      var email: String
      var uid: String
      var fullName: String
      var nickname: String = ""
      
      init(profileImageUrl: String? = nil, email: String = "", uid: String = "", fullName: String = "") {
        if let profileImageUrl, profileImageUrl.isNotEmpty,
           let url = URL(string: profileImageUrl)
        {
          self.profileImage = .url(url)
        } else {
          self.profileImage = .none
        }
        self.email = email
        self.uid = uid
        self.fullName = fullName
        self.nickname = fullName.isEmpty ? "" : fullName
      }
    }
    
    public enum Action {
      case nicknameChanged(String)
      case photoSelected(PhotosPickerItem?)
      case photoLoaded(Data?)
      case saveTapped
      case delegate(Delegate)
    }
    
    public enum Delegate: Equatable {
      case completed
    }
    
    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .nicknameChanged(let name):
          state.nickname = name
          return .none
          
        case .photoSelected(let item):
          if let item {
            return .run { send in
              if let data = try? await item.loadTransferable(type: Data.self) {
                await send(.photoLoaded(data))
              }
            }
          } else {
            return .none
          }
          
        case .photoLoaded(let data):
          state.profileImage = .data(data)
          return .none
          
        case .saveTapped:
          return .send(.delegate(.completed))
          
        case .delegate:
          return .none
        }
      }
    }
    
    public struct View: SwiftUI.View {
      @Bindable private var store: StoreOf<ProfileSetup>
      
      public init(store: StoreOf<ProfileSetup>) {
        self.store = store
      }
      
      public var body: some SwiftUI.View {
        ScrollView {
          VStack(spacing: 24) {
            PhotoSection(
              profileImage: store.profileImage,
              selectedPhoto:   $store.selectedPhoto.sending(\.photoSelected)
            )
            
            NicknameSection(
              nickname: Binding(
                get: { store.nickname },
                set: { store.send(.nicknameChanged($0)) }
              )
            )
            
            Button("저장") {
              store.send(.saveTapped)
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.borderedProminent)
            .disabled(store.nickname.isEmpty)
            
            Spacer()
          }
          .padding(.horizontal, 20)
          .padding(.vertical, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture { endEditing() }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("프로필 설정")
        .navigationBarTitleDisplayMode(.inline)
        
      }
      
      private func endEditing() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
      }
    }
  }
}

private struct PhotoSection: View {
  let profileImage: ProfileImageType
  @Binding var selectedPhoto: PhotosPickerItem?
  
  var body: some View {
    PhotosPicker(selection: $selectedPhoto, matching: .images) {
      ZStack {
        Circle()
          .fill(Color(.systemGray6))
          .frame(width: 120, height: 120)
        
        profileImageView
      }
    }
    .frame(maxWidth: .infinity)
    .padding()
    .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
  }
  
  private var profileImageView: some View {
    Group {
      switch profileImage {
      case .url(let url):
        AsyncImage(url: url) { image in
          image
            .resizable()
            .scaledToFill()
            .frame(width: 120, height: 120)
            .clipShape(Circle())
        } placeholder: {
          ProgressView()
        }
      case .data(let data):
        if let data, let image = UIImage(data: data) {
          Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 120, height: 120)
            .clipShape(Circle())
        } else {
          Circle()
            .fill(Color(.systemGray6))
            .frame(width: 120, height: 120)
        }
      case .none:
        Circle()
          .fill(Color(.systemGray6))
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

private struct NicknameSection: View {
  @Binding var nickname: String
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("닉네임 설정")
        .font(.headline)
      
      TextField("닉네임", text: $nickname)
        .textFieldStyle(.roundedBorder)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
  }
}

#Preview("ProfileSetup Preview with ProfileImage") {
  NavigationStack {
    AppEntry.ProfileSetup.View(
      store: Store(
        initialState: AppEntry.ProfileSetup.State(
          profileImageUrl: nil,
          
          email: "sample@promiso.app",
          uid: "uid-1234",
          fullName: "홍길동"
        )
      ) {
        AppEntry.ProfileSetup()
      }
    )
  }
}

#Preview("ProfileSetup Preview with NonProfileImage") {
  NavigationStack {
    AppEntry.ProfileSetup.View(
      store: Store(
        initialState: AppEntry.ProfileSetup.State(
          profileImageUrl: "https://picsum.photos/200/300",
          
          email: "sample@promiso.app",
          uid: "uid-1234",
          fullName: "홍길동"
        )
      ) {
        AppEntry.ProfileSetup()
      }
    )
  }
}
