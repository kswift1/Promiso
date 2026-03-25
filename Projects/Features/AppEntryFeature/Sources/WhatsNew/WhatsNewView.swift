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
      let currentItem = model.items[safe: store.currentIndex]
      let isLast = store.currentIndex == model.items.count - 1

      ZStack(alignment: .bottom) {
        // Background
        Color.black

        // Image area (상단)
        VStack {
          if let item = currentItem {
            imageSection(item: item)
          }
          Spacer()
        }
        .padding(.top, 60)
        .padding(.bottom, 260)

        // Bottom panel (텍스트 + 인디케이터 + 버튼)
        VStack(spacing: 10) {
          // Text
          if let item = currentItem {
            textSection(item: item)
          }

          // Indicator
          if model.items.count > 1 {
            indicatorSection(count: model.items.count, currentIndex: store.currentIndex)
          }

          // Buttons
          buttonRow(isLast: isLast)
        }
        .padding(.top, 20)
        .padding(.horizontal, 15)
        .frame(height: 250)
        .background {
          bottomGradient
        }

        // Close button (우측 상단)
        closeButton
      }
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

