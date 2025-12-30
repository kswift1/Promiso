import Foundation

public enum UserProfileImageInput: Equatable, Sendable {
  case skip
  case data(Data?)
  case url(URL)
  case none
}
