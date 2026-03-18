// MARK: - {Name}View Template
// 사용법: {Name}을 실제 Feature 이름으로 교체

import SwiftUI
import ComposableArchitecture
import PromisoShared
import ResourceKit
import SharedFeature

extension {Name} {
  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      ScrollView {
        VStack(spacing: 16) {
          headerSection
          contentSection
        }
        .padding(.horizontal, 16)
      }
      .auroraBackground()
      .navigationTitle(LocalizedStrings.{Name}.title)
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        store.send(.view(.onAppear))
      }
      // Sheet 네비게이션 (필요 시)
      // .sheet(
      //   item: $store.scope(state: \.destination, action: \.destination)
      // ) { destinationStore in
      //   // destination view
      // }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
      VStack(alignment: .leading, spacing: 8) {
        Text(LocalizedStrings.{Name}.header)
          .font(.title2.bold())
          .foregroundStyle(Color.pmtext.primary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentSection: some View {
      if store.isLoading {
        ProgressView()
          .frame(maxWidth: .infinity, minHeight: 200)
      } else if store.isEmpty {
        emptyView
      } else {
        itemListView
      }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyView: some View {
      VStack(spacing: 12) {
        Image(systemName: "tray")
          .font(.system(size: 48))
          .foregroundStyle(Color.pmgray.n300)
        Text(LocalizedStrings.{Name}.empty)
          .font(.body)
          .foregroundStyle(Color.pmtext.secondary)
      }
      .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - Item List

    @ViewBuilder
    private var itemListView: some View {
      LazyVStack(spacing: 12) {
        ForEach(store.items) { item in
          itemRow(item)
        }
      }
    }

    // MARK: - Item Row

    @ViewBuilder
    private func itemRow(_ item: Item) -> some View {
      Button {
        store.send(.view(.itemTapped(item.id)))
      } label: {
        HStack(spacing: 12) {
          Text(item.title)
            .font(.body)
            .foregroundStyle(Color.pmtext.primary)
          Spacer()
          Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundStyle(Color.pmgray.n400)
        }
        .padding(16)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .adaptiveGlassCard(cornerRadius: 14)
    }
  }
}

// MARK: - Preview

#Preview {
  NavigationStack {
    {Name}.RootView(
      store: Store(initialState: {Name}.Feature.State()) {
        {Name}.Feature()
      }
    )
  }
}
