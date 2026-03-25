// MARK: - WhatsNewView.swift
import ComposableArchitecture
import PromisoShared
import ResourceKit
import SwiftUI

extension WhatsNew {
  public struct ContentView: View {
    @Bindable var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      ZStack {
        if store.isLoading {
          Color.black
        } else if let model = store.model {
          whatsNewContent(model: model)
        }
      }
      .ignoresSafeArea()
      .preferredColorScheme(.dark)
      .onAppear {
        store.send(.view(.onAppear))
      }
    }

    @ViewBuilder
    private func whatsNewContent(model: WhatsNewModel) -> some View {
      let isCover = store.currentIndex == 0
      let itemIndex = store.currentIndex - 1
      let currentItem = isCover ? nil : model.items[safe: itemIndex]
      let totalPages = model.items.count + 1
      let isLast = store.currentIndex == model.items.count

      ZStack(alignment: .bottom) {
        // Background
        Color.black

        if isCover {
          // 표지 페이지
          coverPage(version: model.version)
        } else {
          // Item 페이지
          VStack {
            if let item = currentItem {
              imageSection(item: item)
            }
            Spacer()
          }
          .padding(.top, 60)
          .padding(.bottom, 260)
        }

        // Bottom panel (텍스트 + 인디케이터 + 버튼)
        if !isCover {
          VStack(spacing: 10) {
            if let item = currentItem {
              textSection(item: item)
            }

            if totalPages > 2 {
              indicatorSection(count: model.items.count, currentIndex: itemIndex)
            }

            buttonRow(isLast: isLast)
          }
          .padding(.top, 20)
          .padding(.horizontal, 15)
          .frame(height: 250)
          .background {
            bottomGradient
          }
        }

        // Close button (우측 상단)
        closeButton
      }
    }

    private var appIcon: UIImage? {
      guard let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
            let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
            let iconName = iconFiles.last else { return nil }
      return UIImage(named: iconName)
    }

    // MARK: - Cover Page

    @ViewBuilder
    private func coverPage(version: String) -> some View {
      VStack(spacing: 0) {
        Spacer()
        Spacer()

        // 앱 아이콘 + 글로우
        ZStack {
          Circle()
            .fill(
              RadialGradient(
                colors: [Color.pmindigo.n500.opacity(0.4), .clear],
                center: .center,
                startRadius: 30,
                endRadius: 120
              )
            )
            .frame(width: 240, height: 240)

          if let icon = appIcon {
            Image(uiImage: icon)
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 100, height: 100)
              .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
              .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
          }
        }

        VStack(spacing: 8) {
          Text("What's New")
            .font(.largeTitle)
            .fontWeight(.bold)
            .foregroundStyle(.white)

          Text("Promiso v\(version)의 새로운 기능을 소개합니다")
            .font(.callout)
            .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.top, 4)

        Spacer()
        Spacer()
        Spacer()

        // 시작 버튼
        if #available(iOS 26, *) {
          Button {
            withAnimation(.interpolatingSpring(duration: 0.65, bounce: 0)) {
              _ = store.send(.view(.nextTapped))
            }
          } label: {
            Text("살펴보기")
              .fontWeight(.medium)
              .padding(.vertical, 6)
          }
          .tint(Color.pmindigo.n500)
          .buttonStyle(.glassProminent)
          .buttonSizing(.flexible)
        } else {
          Button {
            withAnimation(.interpolatingSpring(duration: 0.65, bounce: 0)) {
              _ = store.send(.view(.nextTapped))
            }
          } label: {
            Text("살펴보기")
              .fontWeight(.medium)
              .frame(maxWidth: .infinity)
              .frame(height: 44)
              .contentShape(Rectangle())
          }
          .buttonStyle(.borderedProminent)
          .tint(Color.pmindigo.n500)
        }
      }
      .padding(.horizontal, 30)
      .padding(.bottom, 60)
    }

    // MARK: - Image Section

    @ViewBuilder
    private func imageSection(item: WhatsNewModel.Item) -> some View {
      if let imageURL = item.imageURL {
        AsyncImage(url: imageURL) { phase in
          switch phase {
          case .success(let image):
            image
              .resizable()
              .aspectRatio(contentMode: .fit)
              .clipShape(RoundedRectangle(cornerRadius: 20))
          case .failure:
            imagePlaceholder
          case .empty:
            ProgressView()
              .tint(.white)
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          @unknown default:
            imagePlaceholder
          }
        }
        .padding(.horizontal, 30)
      } else {
        imagePlaceholder
      }
    }

    private var imagePlaceholder: some View {
      RoundedRectangle(cornerRadius: 20)
        .fill(Color.white.opacity(0.05))
        .overlay {
          Image(systemName: "photo")
            .font(.largeTitle)
            .foregroundStyle(.white.opacity(0.2))
        }
        .padding(.horizontal, 30)
    }

    // MARK: - Text Section

    @ViewBuilder
    private func textSection(item: WhatsNewModel.Item) -> some View {
      VStack(spacing: 6) {
        Text(item.title)
          .font(.title2)
          .fontWeight(.semibold)
          .lineLimit(2)
          .multilineTextAlignment(.center)
          .foregroundStyle(.white)

        Text(item.description)
          .font(.callout)
          .lineLimit(4)
          .multilineTextAlignment(.center)
          .foregroundStyle(.white.opacity(0.8))
      }
      .padding(.horizontal, 20)
    }

    // MARK: - Indicator

    @ViewBuilder
    private func indicatorSection(count: Int, currentIndex: Int) -> some View {
      HStack(spacing: 6) {
        ForEach(0..<count, id: \.self) { index in
          Capsule()
            .fill(.white.opacity(index == currentIndex ? 1 : 0.4))
            .frame(width: index == currentIndex ? 25 : 6, height: 6)
        }
      }
      .padding(.bottom, 5)
      .animation(.easeInOut(duration: 0.25), value: currentIndex)
    }

    // MARK: - Button Row

    @ViewBuilder
    private func buttonRow(isLast: Bool) -> some View {
      HStack(spacing: 12) {
        // Back button
        if store.currentIndex > 0 {
          if #available(iOS 26, *) {
            Button {
              withAnimation(.interpolatingSpring(duration: 0.65, bounce: 0)) {
                _ = store.send(.view(.previousTapped))
              }
            } label: {
              Image(systemName: "chevron.left")
                .font(.body.weight(.medium))
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
          } else {
            Button {
              withAnimation(.interpolatingSpring(duration: 0.65, bounce: 0)) {
                _ = store.send(.view(.previousTapped))
              }
            } label: {
              Image(systemName: "chevron.left")
                .font(.body.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.15), in: Circle())
            }
          }
        }

        // Continue / Done button
        if #available(iOS 26, *) {
          Button {
            withAnimation(.interpolatingSpring(duration: 0.65, bounce: 0)) {
              _ = store.send(.view(.nextTapped))
            }
          } label: {
            Text(isLast ? LocalizedStrings.Common.done : LocalizedStrings.Common.next)
              .fontWeight(.medium)
              .contentTransition(.numericText())
              .padding(.vertical, 6)
          }
          .tint(Color.pmindigo.n500)
          .buttonStyle(.glassProminent)
          .buttonSizing(.flexible)
        } else {
          Button {
            withAnimation(.interpolatingSpring(duration: 0.65, bounce: 0)) {
              _ = store.send(.view(.nextTapped))
            }
          } label: {
            Text(isLast ? LocalizedStrings.Common.done : LocalizedStrings.Common.next)
              .fontWeight(.medium)
              .contentTransition(.numericText())
              .frame(maxWidth: .infinity)
              .frame(height: 44)
              .contentShape(Rectangle())
          }
          .buttonStyle(.borderedProminent)
          .tint(Color.pmindigo.n500)
        }
      }
      .padding(.horizontal, 20)
    }

    // MARK: - Close Button

    @ViewBuilder
    private var closeButton: some View {
      if #available(iOS 26, *) {
        Button {
          store.send(.view(.dismissTapped))
        } label: {
          Image(systemName: "xmark")
            .font(.body.weight(.medium))
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.trailing, 15)
        .padding(.top, 55)
      } else {
        Button {
          store.send(.view(.dismissTapped))
        } label: {
          Image(systemName: "xmark")
            .font(.body.weight(.medium))
            .foregroundStyle(.white.opacity(0.7))
            .frame(width: 44, height: 44)
            .background(Color.white.opacity(0.15), in: Circle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.trailing, 15)
        .padding(.top, 55)
      }
    }

    // MARK: - Bottom Gradient

    private var bottomGradient: some View {
      LinearGradient(
        colors: [
          Color.black.opacity(0.95),
          Color.black.opacity(0.85),
          Color.black.opacity(0.6),
          Color.clear,
        ],
        startPoint: .bottom,
        endPoint: .top
      )
      .padding(.top, -30)
      .ignoresSafeArea()
    }
  }
}

