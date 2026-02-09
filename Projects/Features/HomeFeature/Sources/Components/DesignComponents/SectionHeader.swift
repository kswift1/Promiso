//
//  SectionHeader.swift
//  HomeFeatureImplement
//
//  Created by 김성원 on 9/15/25.
//

import SwiftUI
import ResourceKit

struct SectionHeader<Accessory: View>: View {
  private let title: String
  private let accessoryView: () -> Accessory
  
  init(
    title: String,
    @ViewBuilder accessoryView: @escaping () -> Accessory = { EmptyView() }
  ) {
    self.title = title
    self.accessoryView = accessoryView
  }
  
  var body: some View {
    HStack {
      Text(title)
        .font(.pmTitle3Semibold)
      
      Spacer()
      
      accessoryView()
    }
  }
}
