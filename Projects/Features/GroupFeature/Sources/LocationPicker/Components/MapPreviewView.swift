//
//  MapPreviewView.swift
//  GroupFeature
//

import SwiftUI
import Clients
import ResourceKit
import PromisoShared

// MARK: - Map Preview View
// KakaoMiniMapView를 래핑하여 Coordinate 타입을 받을 수 있도록 함

struct MapPreviewView: View {
  let coordinate: Coordinate

  var body: some View {
    KakaoMiniMapView(
      latitude: coordinate.latitude,
      longitude: coordinate.longitude,
      zoomLevel: 15,
      markerImage: ResourceKitAsset.mapPinMini.image
    )
  }
}
