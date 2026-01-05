//
//  SplashView.swift
//  AppEntryFeature
//
//  Created by 김성원 on 12/11/25.
//

import SwiftUI
import PromisoShared
import ResourceKit

struct SplashConfig {
  var initialDelay: Double = 0.5
  var scaling: CGFloat = 4
  var forceHideLogo: Bool = false
  /// For Even More Customiaztion
  var animation: Animation = .smooth(duration: 1, extraBounce: 0)
}

struct SplashView<Logo: View>: View {
  var config: SplashConfig
  @ViewBuilder var logo: Logo
  var animateOut: Bool
  var isCompleted: () -> ()
  /// View Properties
  @State private var scaleDown: Bool = false
  @State private var scaleUp: Bool = false
  @State private var started: Bool = false
  var body: some View {
    ZStack {
      // 1. Base Background Color
      Color(UIColor.systemGray6)
        .ignoresSafeArea()
      
      // 2. Aurora/Gradient Blobs
      AuroraBackgroundView()
    }
    /// Reverse Logo Masking!
    .mask {
      GeometryReader {
        let size = $0.size.applying(.init(scaleX: config.scaling, y: config.scaling))
        
        Rectangle()
          .overlay {
            logo
              .offset(y: 14)
              .blur(radius: config.forceHideLogo ? 0 : (scaleUp ? 15 : 0))
              .blendMode(.destinationOut)
              .animation(.smooth(duration: 0.3, extraBounce: 0)) { content in
                content
                  .scaleEffect(scaleDown ? 0.8 : 1)
              }
              .visualEffect { [scaleUp] content, proxy in
                let scaleX: CGFloat = size.width / proxy.size.width
                let scaleY: CGFloat = size.height / proxy.size.height
                /// Logo Size based Scaling!
                let maxScale = Swift.max(scaleX, scaleY)
                return content
                  .scaleEffect(scaleUp ? maxScale : 1)
              }
          }
      }
    }
    .opacity(config.forceHideLogo ? 1 : (scaleUp ? 0 : 1 ))
    .background {
      Rectangle()
        .fill(.linearGradient(
          colors: [
            Color.logobg.primary,
            Color.logobg.secondary,
          ],
          startPoint: .leading,
          endPoint: .trailing
        ))
        .opacity(scaleUp ? 0 : 1)
    }
    .ignoresSafeArea()
    .task { await startIfNeeded(animateOut) }
    .onChange(of: animateOut, { _, newValue in
      Task { await startIfNeeded(newValue) }
    })
  }
  
  @MainActor
  private func startIfNeeded(_ shouldStart: Bool) async {
    guard shouldStart, !started else { return }
    started = true
    try? await Task.sleep(for: .seconds(config.initialDelay))
    scaleDown = true
    try? await Task.sleep(for: .seconds(0.1))
    withAnimation(config.animation, completionCriteria: .logicallyComplete) {
      scaleUp = true
    } completion: {
      isCompleted()
    }
  }
}
