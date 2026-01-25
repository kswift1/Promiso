import Foundation

public enum GroupInviteShareMessage {
  public static func message(groupName: String, inviteCode: String) -> String {
    let deeplink = deeplinkURL(inviteCode: inviteCode).absoluteString
    return """
    \(groupName) 그룹에 초대합니다 🎉!

    1) 앱 설치하기
    앱스토어 링크: "TODO: AppsStore Link"

    2) 초대장 링크를 클릭 또는 그룹 탭 > 친구 초대 > 초대 코드 입력
    초대장 링크: \(deeplink) 
    
    초대 코드: \(inviteCode)
    """
  }

  public static func deeplinkURL(inviteCode: String) -> URL {
    URL(string: "promiso://join/\(inviteCode)")!
  }
}
