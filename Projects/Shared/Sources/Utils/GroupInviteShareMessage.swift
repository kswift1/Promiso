import Foundation
import SwiftUI

public enum GroupInviteShareMessage {
  public static func message(groupName: String, inviteCode: String) -> String {
    let deeplink = deeplinkURL(inviteCode: inviteCode).absoluteString
    let appstoreLink = "https://apps.apple.com/app/id6757733720"
    return """
    \(groupName) 그룹에 초대합니다! 🎉 
    초대 코드: \(inviteCode)

    1) 앱 설치: \(appstoreLink)
    2) 참여: \(deeplink)
    (또는 그룹 탭 > 친구 초대 > 코드 입력)
    """
  }

  public static func shareLink<Label: View>(
    groupName: String,
    inviteCode: String,
    @ViewBuilder label: () -> Label
  ) -> some View {
    ShareLink(item: message(groupName: groupName, inviteCode: inviteCode), label: label)
  }

  private static func deeplinkURL(inviteCode: String) -> URL {
    URL(string: "promiso://join/\(inviteCode)")!
  }
}
