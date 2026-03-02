import SwiftUI
import Clients
import PromisoShared
import ResourceKit

public struct PromiseDetailSectionHeader: View {
  private let title: String
  private let trailing: String?

  public init(title: String, trailing: String? = nil) {
    self.title = title
    self.trailing = trailing
  }

  public var body: some View {
    HStack {
      Text(title)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.secondary)
        .textCase(.uppercase)

      Spacer()

      if let trailing {
        Text(trailing)
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.secondary)
      }
    }
    .padding(.horizontal, 4)
    .padding(.bottom, 8)
  }
}

public struct PromiseDetailExpandableText: View {
  private let text: String
  @Binding private var isExpanded: Bool
  @State private var isTruncated = false
  private let lineLimit = 3
  
  public init(text: String, isExpanded: Binding<Bool>) {
    self.text = text
    self._isExpanded = isExpanded
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(text)
        .font(.system(size: 14))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.leading)
        .lineLimit(isExpanded ? nil : lineLimit)
        .background(
          GeometryReader { geometry in
            Color.clear.onAppear {
              checkTruncation(geometry: geometry)
            }
          }
        )

      if isTruncated || isExpanded {
        Button {
          withAnimation(.easeInOut(duration: 0.2)) {
            isExpanded.toggle()
          }
        } label: {
          Text(isExpanded ? LocalizedStrings.Common.collapse : LocalizedStrings.Common.seeMore)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.blue)
        }
      }
    }
  }

  private func checkTruncation(geometry: GeometryProxy) {
    let font = UIFont.systemFont(ofSize: 15)
    let attributes: [NSAttributedString.Key: Any] = [.font: font]
    let size = CGSize(width: geometry.size.width, height: .greatestFiniteMagnitude)
    let boundingRect = (text as NSString).boundingRect(
      with: size,
      options: [.usesLineFragmentOrigin, .usesFontLeading],
      attributes: attributes,
      context: nil
    )
    let lineHeight = font.lineHeight
    let numberOfLines = Int(ceil(boundingRect.height / lineHeight))
    isTruncated = numberOfLines > lineLimit
  }
}

public struct PromiseDetailEmojiInfoRow: View {
  private let emoji: String
  private let title: String
  private let value: String

  public init(emoji: String, title: String, value: String) {
    self.emoji = emoji
    self.title = title
    self.value = value
  }

  public var body: some View {
    HStack(spacing: 10) {
      Text(emoji)
        .font(.system(size: 18))
        .frame(width: 28)

      Text(title)
        .font(.system(size: 15))
        .foregroundStyle(.secondary)

      Spacer()

      Text(value)
        .font(.system(size: 15, weight: .medium))
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
  }
}

public struct PromiseDetailLocationInfoRow: View {
  private let location: LocationInfoModel

  public init(location: LocationInfoModel) {
    self.location = location
  }

  public var body: some View {
    HStack(spacing: 10) {
      Text("📍")
        .font(.system(size: 18))
        .frame(width: 28)

      VStack(alignment: .leading, spacing: 2) {
        Text(location.name)
          .font(.system(size: 15, weight: .medium))

        if let address = location.address {
          Text(address)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
        }
      }

      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
  }
}

public struct PromiseDetailParticipantGroupRow: View {
  private let title: String
  private let count: Int
  private let userIds: [String]
  private let members: [UserPublicModel]?
  private let color: Color
  private let onTap: () -> Void

  public init(
    title: String,
    count: Int,
    userIds: [String],
    members: [UserPublicModel]?,
    color: Color,
    onTap: @escaping () -> Void
  ) {
    self.title = title
    self.count = count
    self.userIds = userIds
    self.members = members
    self.color = color
    self.onTap = onTap
  }

  public var body: some View {
    Button(action: onTap) {
      HStack {
        Circle()
          .fill(color)
          .frame(width: 8, height: 8)

        Text(title)
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(.primary)

        Text("\(count)명")
          .font(.system(size: 14))
          .foregroundStyle(.secondary)

        Spacer()

        HStack(spacing: -8) {
          ForEach(userIds.prefix(5), id: \.self) { userId in
            if let member = members?.first(where: { $0.userId == userId }) {
              ProfileAvatarView(
                profileImageUrl: member.profileImageUrl,
                displayName: member.displayName,
                size: 28
              )
            } else {
              ProfileAvatarView(
                profileImageUrl: nil,
                displayName: "?",
                size: 28
              )
            }
          }

          if userIds.count > 5 {
            Text("+\(userIds.count - 5)")
              .font(.system(size: 10, weight: .bold))
              .foregroundColor(.white)
              .frame(width: 28, height: 28)
              .background(Color.gray)
              .clipShape(Circle())
              .overlay(Circle().stroke(Color.white, lineWidth: 2))
          }
        }

        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.tertiary)
      }
      .contentShape(Rectangle())
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .adaptiveGlassCard(cornerRadius: 12)
    }
    .buttonStyle(.plain)
  }
}

public struct PromiseDetailLocationMapPreview: View {
  private let latitude: Double
  private let longitude: Double
  private let placeName: String
  private let onTap: () -> Void

  public init(
    latitude: Double,
    longitude: Double,
    placeName: String,
    onTap: @escaping () -> Void
  ) {
    self.latitude = latitude
    self.longitude = longitude
    self.placeName = placeName
    self.onTap = onTap
  }

  public var body: some View {
    Button(action: onTap) {
      ZStack(alignment: .topTrailing) {
        KakaoMiniMapView(
          latitude: latitude,
          longitude: longitude,
          zoomLevel: 16
        )
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 12))

        // 확대 아이콘 (우상단, 네모 배경)
        ResourceKitAsset.expandIcon.swiftUIImage
          .resizable()
          .renderingMode(.template)
          .foregroundStyle(.black.opacity(0.6))
          .frame(width: 16, height: 16)
          .padding(4)
          .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
          .padding(8)
      }
      .contentShape(Rectangle())
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
    }
    .buttonStyle(.plain)
  }
}

public struct PromiseDetailStatusBadgeView: View {
  private let status: PromiseResponseStatus

  public init(status: PromiseResponseStatus) {
    self.status = status
  }

  private var displayText: String {
    switch status {
    case .needResponse:
      return LocalizedStrings.Shared.statusNeedResponse
    case .responded:
      return LocalizedStrings.Shared.statusWaitingConfirm
    case .confirmed:
      return LocalizedStrings.Shared.statusConfirmed
    case .failed:
      return LocalizedStrings.Shared.statusFailed
    }
  }

  private var color: Color {
    switch status {
    case .needResponse:
      return .orange
    case .responded:
      return .blue
    case .confirmed:
      return .green
    case .failed:
      return .gray
    }
  }

  public var body: some View {
    HStack(spacing: 4) {
      Image(systemName: status.iconName)
        .font(.system(size: 12))
      Text(displayText)
        .font(.system(size: 13, weight: .semibold))
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(color.opacity(0.15))
    .foregroundStyle(color)
    .clipShape(Capsule())
  }
}

public struct PromiseDetailMemberListSheet: View {
  private let title: String
  private let members: [UserPublicModel]
  private let color: Color

  @State private var selectedMember: UserPublicModel?
  
  public init(title: String, members: [UserPublicModel], color: Color) {
    self.title = title
    self.members = members
    self.color = color
    self._selectedMember = State(initialValue: nil)
  }

  public var body: some View {
    NavigationView {
      ScrollView {
        LazyVStack(spacing: 0) {
          ForEach(members) { member in
            PromiseDetailMemberRow(member: member, color: color) {
              selectedMember = member
            }

            if member.id != members.last?.id {
              Divider().padding(.leading, 72)
            }
          }
        }
        .padding(.vertical, 8)
      }
      .navigationTitle("\(title) (\(members.count)명)")
      .navigationBarTitleDisplayMode(.inline)
    }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    .fullScreenCover(item: $selectedMember) { member in
      ImageDetailView(
        imageUrl: member.profileImageUrl,
        displayName: member.displayName,
        onDismiss: { selectedMember = nil }
      )
      .presentationBackground(.black)
    }
  }
}

public struct PromiseDetailMemberRow: View {
  private let member: UserPublicModel
  private let color: Color
  private let onProfileTap: () -> Void

  public init(member: UserPublicModel, color: Color, onProfileTap: @escaping () -> Void) {
    self.member = member
    self.color = color
    self.onProfileTap = onProfileTap
  }

  public var body: some View {
    HStack(spacing: 16) {
      ProfileAvatarView(
        profileImageUrl: member.profileImageUrl,
        displayName: member.displayName,
        size: 48,
        borderWidth: 0,
        onTap: onProfileTap
      )

      VStack(alignment: .leading, spacing: 4) {
        Text(member.displayName)
          .font(.system(size: 16, weight: .medium))
          .foregroundStyle(.primary)

        if !member.nickname.isEmpty && member.nickname != member.displayName {
          Text("@\(member.nickname)")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
        }
      }

      Spacer()

      Circle()
        .fill(color)
        .frame(width: 10, height: 10)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
  }
}
