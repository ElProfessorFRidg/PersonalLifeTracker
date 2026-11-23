import SwiftUI

/// Onboarding en sept étapes (design/SCREENS.md). Appelle `onDone` à la fin : RootView affiche alors les onglets.
struct OnboardingView: View {
    let onDone: () -> Void

    @Environment(\.palette) private var palette
    @Environment(\.pltReduceAnimations) private var reduceAnimations
    @Environment(ModuleStore.self) private var modules

    @State private var step: OnboardingStep = .welcome
    @State private var permissions: PermissionRequester = PermissionRequester()
    @State private var firstPlace: OnboardingPlaceSummary? = nil

    private var enabled: Set<String> { return modules.enabledIDs }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                stepContent
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.top, Theme.Spacing.s)
                    .padding(.bottom, Theme.Spacing.l)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(step)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(palette.background.ignoresSafeArea())
    }

    // MARK: En-tête

    private var header: some View {
        let position = OnboardingFlow.position(of: step, enabledModules: enabled)
        let canGoBack: Bool = OnboardingFlow.previous(before: step, enabledModules: enabled) != nil
        let canSkip: Bool = step == .location || step == .notifications || step == .photos || step == .firstPlace
        return VStack(spacing: Theme.Spacing.s) {
            HStack {
                Button {
                    goBack()
                } label: {
                    Label("Retour", systemImage: "chevron.left")
                        .font(.body)
                        .frame(minHeight: 44)
                }
                .opacity(canGoBack ? 1 : 0)
                .disabled(!canGoBack)
                .accessibilityHidden(!canGoBack)
                Spacer()
                if let position = position {
                    Text("Étape \(position.number) sur \(position.total)")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(palette.textSecondary)
                }
                Spacer()
                Button("Plus tard") {
                    goNext()
                }
                .font(.body)
                .frame(minHeight: 44)
                .opacity(canSkip ? 1 : 0)
                .disabled(!canSkip)
                .accessibilityHidden(!canSkip)
            }
            if let position = position {
                OnboardingProgressBar(number: position.number, total: position.total)
            }
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.top, Theme.Spacing.s)
    }

    // MARK: Contenu

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome:
            OnboardingWelcomeStep(onContinue: { goNext() })
        case .modules:
            OnboardingModulesStep(onContinue: { goNext() })
        case .location:
            OnboardingLocationStep(permissions: permissions, onContinue: { goNext() })
        case .notifications:
            OnboardingNotificationsStep(permissions: permissions, onContinue: { goNext() })
        case .photos:
            OnboardingPhotosStep(onContinue: { goNext() })
        case .firstPlace:
            OnboardingPlaceStep(permissions: permissions,
                                created: firstPlace,
                                onCreated: { summary in firstPlace = summary },
                                onContinue: { goNext() })
        case .ready:
            OnboardingReadyStep(permissions: permissions,
                                place: firstPlace,
                                goTo: { target in move(to: target) },
                                onDone: onDone)
        }
    }

    // MARK: Navigation

    private func goNext() {
        if let next = OnboardingFlow.next(after: step, enabledModules: enabled) {
            move(to: next)
        }
    }

    private func goBack() {
        if let previous = OnboardingFlow.previous(before: step, enabledModules: enabled) {
            move(to: previous)
        }
    }

    private func move(to target: OnboardingStep) {
        if reduceAnimations {
            step = target
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                step = target
            }
        }
    }
}
