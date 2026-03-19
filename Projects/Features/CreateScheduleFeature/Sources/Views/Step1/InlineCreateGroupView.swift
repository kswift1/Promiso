import SwiftUI
import Clients
import ComposableArchitecture
import PromisoShared

// MARK: - Inline Create Group View

struct InlineCreateGroupView: View {
  private let store: StoreOf<CreateSchedule.Feature>
  @FocusState private var isNameFocused: Bool

  init(store: StoreOf<CreateSchedule.Feature>) {
    self.store = store
  }

  var body: some View {
    NavigationStack {
      ZStack {
        backgroundView

        ScrollView {
          VStack(spacing: 28) {
            headerIcon
            nameSection
            maxMembersSection

            if let error = store.groupCreationError {
              errorView(message: error)
            }

            Spacer(minLength: 20)
            createButton
          }
          .padding(20)
        }
      }
      .navigationTitle(LocalizedStrings.CreateSchedule.inlineCreateGroupTitle)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            store.send(.view(.inlineCreateGroupDismissed))
          } label: {
            Image(systemName: "xmark.circle.fill")
              .font(.system(size: 24))
              .foregroundStyle(Color(.systemGray3))
          }
          .contentShape(Rectangle())
        }
      }
    }
    .onAppear {
      isNameFocused = true
    }
  }

  // MARK: - Background

  @ViewBuilder
  private var backgroundView: some View {
    if #available(iOS 26, *) {
      Color.clear
    } else {
      Color(.systemGroupedBackground)
        .ignoresSafeArea()
    }
  }

  // MARK: - Header Icon

  private var headerIcon: some View {
    ZStack {
      Circle()
        .fill(
          LinearGradient(
            colors: [Color.pmindigo.n100, Color.pmpurple.n100],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .frame(width: 80, height: 80)

      Image(systemName: "person.2.fill")
        .font(.system(size: 34))
        .foregroundStyle(
          LinearGradient(
            colors: [Color.pmindigo.n500, Color.pmpurple.n500],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
    }
    .padding(.top, 8)
  }

  // MARK: - Name Section

  private var nameSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(LocalizedStrings.CreateSchedule.inlineGroupNameLabel)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.secondary)

      HStack {
        TextField(
          LocalizedStrings.CreateSchedule.inlineGroupNamePlaceholder,
          text: Binding(
            get: { store.inlineGroupName },
            set: { store.send(.view(.setInlineGroupName($0))) }
          )
        )
        .focused($isNameFocused)
        .font(.system(size: 17))
        .submitLabel(.done)
        .onSubmit {
          if store.canSubmitInlineGroup && !store.isCreatingGroup {
            store.send(.view(.submitInlineCreateGroup))
          }
        }

        Spacer()

        let count = store.inlineGroupName.count
        let isValid = store.canSubmitInlineGroup
        Text("\(count)/12")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(isValid ? Color.pmsuccess.n500 : Color(.systemGray3))
          .animation(.easeInOut(duration: 0.2), value: isValid)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(Color(.systemBackground))
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(
                isNameFocused ? Color.pmindigo.n500 : Color(.systemGray5),
                lineWidth: isNameFocused ? 2 : 1
              )
              .animation(.easeInOut(duration: 0.2), value: isNameFocused)
          )
      )
    }
  }

  // MARK: - Max Members Section

  private var maxMembersSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(LocalizedStrings.CreateSchedule.inlineGroupMaxMembersLabel)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.secondary)

      HStack {
        Text(LocalizedStrings.CreateSchedule.inlineGroupMaxMembersCount(store.inlineGroupMaxMembers))
          .font(.system(size: 17))
          .foregroundStyle(.primary)

        Spacer()

        HStack(spacing: 0) {
          Button {
            store.send(.view(.setInlineGroupMaxMembers(store.inlineGroupMaxMembers - 1)))
          } label: {
            Image(systemName: "minus")
              .font(.system(size: 16, weight: .semibold))
              .frame(width: 44, height: 44)
              .foregroundStyle(store.inlineGroupMaxMembers <= 2 ? Color(.systemGray3) : Color.pmindigo.n500)
          }
          .contentShape(Rectangle())
          .disabled(store.inlineGroupMaxMembers <= 2)

          Text("\(store.inlineGroupMaxMembers)")
            .font(.system(size: 17, weight: .semibold))
            .frame(width: 36)
            .foregroundStyle(.primary)

          Button {
            store.send(.view(.setInlineGroupMaxMembers(store.inlineGroupMaxMembers + 1)))
          } label: {
            Image(systemName: "plus")
              .font(.system(size: 16, weight: .semibold))
              .frame(width: 44, height: 44)
              .foregroundStyle(store.inlineGroupMaxMembers >= 10 ? Color(.systemGray3) : Color.pmindigo.n500)
          }
          .contentShape(Rectangle())
          .disabled(store.inlineGroupMaxMembers >= 10)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(Color(.systemBackground))
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(Color(.systemGray5), lineWidth: 1)
          )
      )
    }
  }

  // MARK: - Error View

  private func errorView(message: String) -> some View {
    HStack(spacing: 8) {
      Image(systemName: "exclamationmark.circle.fill")
        .font(.system(size: 14))
        .foregroundStyle(Color.pmerror.n500)

      Text(message)
        .font(.system(size: 14))
        .foregroundStyle(Color.pmerror.n500)
        .multilineTextAlignment(.leading)

      Spacer()

      Button {
        store.send(.view(.clearGroupCreationError))
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(Color.pmerror.n500)
      }
      .contentShape(Rectangle())
    }
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: 10)
        .fill(Color.pmerror.n50)
    )
  }

  // MARK: - Create Button

  private var createButton: some View {
    Button {
      store.send(.view(.submitInlineCreateGroup))
    } label: {
      HStack(spacing: 8) {
        if store.isCreatingGroup {
          ProgressView()
            .tint(.white)
            .scaleEffect(0.9)
        } else {
          Image(systemName: "plus.circle.fill")
            .font(.system(size: 18))
        }
        Text(LocalizedStrings.CreateSchedule.inlineCreateGroupButton)
          .font(.headline)
      }
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity)
      .frame(height: 54)
      .background(
        Group {
          if store.canSubmitInlineGroup && !store.isCreatingGroup {
            LinearGradient(
              colors: [Color.pmindigo.n500, Color.pmpurple.n500],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          } else {
            LinearGradient(
              colors: [Color(.systemGray4), Color(.systemGray4)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          }
        }
      )
      .clipShape(RoundedRectangle(cornerRadius: 16))
      .shadow(
        color: (store.canSubmitInlineGroup && !store.isCreatingGroup)
          ? Color.pmindigo.n500.opacity(AppConstants.UI.selectionOpacity)
          : .clear,
        radius: 10,
        x: 0,
        y: 5
      )
      .animation(.easeInOut(duration: 0.2), value: store.canSubmitInlineGroup)
    }
    .contentShape(Rectangle())
    .disabled(!store.canSubmitInlineGroup || store.isCreatingGroup)
    .buttonStyle(PlainButtonStyle())
  }
}
