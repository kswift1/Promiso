import Foundation
import PromisoShared

// MARK: - Coordinate

/// SDK 중립적인 좌표 타입
public struct Coordinate: Equatable, Hashable, Sendable, Codable {
  public let latitude: Double
  public let longitude: Double

  public init(latitude: Double, longitude: Double) {
    self.latitude = latitude
    self.longitude = longitude
  }
}

// MARK: - Place

/// SDK 중립적인 장소 타입
public struct Place: Identifiable, Equatable, Hashable, Sendable {
  public let id: String
  public let name: String
  public let coordinate: Coordinate
  public let address: String?
  public let roadAddress: String?
  public let category: String?
  public let phone: String?

  public init(
    id: String,
    name: String,
    coordinate: Coordinate,
    address: String? = nil,
    roadAddress: String? = nil,
    category: String? = nil,
    phone: String? = nil
  ) {
    self.id = id
    self.name = name
    self.coordinate = coordinate
    self.address = address
    self.roadAddress = roadAddress
    self.category = category
    self.phone = phone
  }

  /// 표시용 주소 (도로명 주소 우선)
  public var displayAddress: String? {
    roadAddress ?? address
  }

  /// LocationInfoModel로 변환
  public func toLocationInfo() -> LocationInfoModel {
    LocationInfoModel(
      name: name,
      address: displayAddress,
      latitude: coordinate.latitude,
      longitude: coordinate.longitude
    )
  }
}
