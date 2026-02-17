//
//  View+KeyboardDismissToolbar.swift
//  PromisoShared
//

import SwiftUI
import ResourceKit
import UIKit

// MARK: - Keyboard Dismiss Toolbar Extension

public extension View {
  /// 키보드 상단 툴바에 "내리기" 버튼을 추가합니다.
  func keyboardDismissToolbar(
    iconColor: Color = Color.pmtext.secondary
  ) -> some View {
    self
      .toolbar {
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
          } label: {
            Image(systemName: "keyboard.chevron.compact.down")
              .foregroundStyle(iconColor)
          }
        }
      }
  }
}
