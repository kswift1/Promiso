//
//  CommonBackGroundView.swift
//  Shared
//
//  Created by 김성원 on 12/10/25.
//

import SwiftUI

import ResourceKit

public struct AuroraBackgroundModifier: ViewModifier {
  public init() { }
  
  public func body(content: Content) -> some View {
    ZStack {
      AuroraBackgroundView()
      content
    }
  }
}

public extension View {
  func auroraBackground() -> some View {
    modifier(AuroraBackgroundModifier())
  }
}

public struct AuroraBackgroundView: View {
  
  public init() { }
  
  public var body: some View {
    GeometryReader { geometry in
      ZStack {
        // Top-Left: Purple (animate-pulse equivalent requires state animation in SwiftUI)
        Circle()
          .fill(Color.pmaurora.purple.opacity(0.3))
          .frame(width: geometry.size.width * 1.4, height: geometry.size.width * 1.4)
          .position(x: geometry.size.width * 0.1, y: geometry.size.height * 0.1)
          .blur(radius: 120)
        
        // Bottom-Right: Indigo
        Circle()
          .fill(Color.pmaurora.indigo.opacity(0.3))
          .frame(width: geometry.size.width * 1.2, height: geometry.size.width * 1.2)
          .position(x: geometry.size.width * 0.9, y: geometry.size.height * 0.9)
          .blur(radius: 120)
        
        // Center-Left: Pink
        Circle()
          .fill(Color.pmaurora.pink.opacity(0.2))
          .frame(width: geometry.size.width * 0.8, height: geometry.size.width * 0.8)
          .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.6)
          .blur(radius: 100)
      }
    }
    .ignoresSafeArea()
  }
}
