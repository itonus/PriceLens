import SwiftUI

/// Scanner root: full-screen camera, overlays, floating chrome, status capsule,
/// result sheet. This is the app's home — there is no intermediate screen.
struct ScannerView: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppSettings.self) private var settings

    @State private var viewModel: ScannerViewModel?
    @State private var showsHistory = false
    @State private var showsSettings = false
    @State private var manualQuery = ""

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let viewModel {
                scannerBody(viewModel)
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .onAppear {
            if viewModel == nil { viewModel = ScannerViewModel(container: container) }
            viewModel?.onAppear()
        }
        .onDisappear { viewModel?.onDisappear() }
    }

    @ViewBuilder
    private func scannerBody(_ viewModel: ScannerViewModel) -> some View {
        @Bindable var vm = viewModel

        ZStack {
            // Layer 1: camera feed (or fixture preview)
            cameraLayer(viewModel)
                .ignoresSafeArea()

            // Layer 2: focus guidance + recognized overlays.
            // Bounds from the scanner arrive in the full-screen (safe-area-ignoring) coordinate
            // space that the camera layer above renders in, so these must ignore the safe area
            // too — otherwise every overlay is offset by the top/bottom safe-area inset.
            if viewModel.permissionState == .authorized {
                focusBrackets
                    .ignoresSafeArea()
                overlaysLayer(viewModel)
                    .ignoresSafeArea()
            }

            // Layer 3: top floating controls
            VStack {
                topControls(viewModel)
                Spacer()
            }

            // Layer 4: bottom status capsule
            VStack {
                Spacer()
                bottomBar(viewModel)
                    .padding(.bottom, Tokens.Spacing.xl)
            }
        }
        .statusBarHidden(false)
        // Lock transition: haptic + sheet
        .sensoryFeedback(.success, trigger: viewModel.lockTrigger)
        .sheet(item: sheetBinding(viewModel)) { session in
            if let results = viewModel.activeResults, results.sessionID == session.id {
                ResultSheetView(viewModel: results)
                    .environment(container)
                    .environment(settings)
            }
        }
        .alert(settings.localized("scanner.manual.title"), isPresented: $vm.showsManualEntry) {
            TextField(settings.localized("scanner.manual.placeholder"), text: $manualQuery)
            Button(settings.localized("action.search")) {
                viewModel.manualSearch(query: manualQuery)
                manualQuery = ""
            }
            Button(settings.localized("action.cancel"), role: .cancel) { manualQuery = "" }
        }
        // History/Settings anchor separately so they can present over the result sheet.
        Color.clear.frame(width: 0, height: 0)
            .sheet(isPresented: $showsHistory) {
                HistoryView(onRerun: { session in
                    showsHistory = false
                    viewModel.rerun(session: session)
                })
                .environment(container)
                .environment(settings)
            }
        Color.clear.frame(width: 0, height: 0)
            .sheet(isPresented: $showsSettings) {
                SettingsView()
                    .environment(container)
                    .environment(settings)
            }
    }

    // MARK: - Layers

    @ViewBuilder
    private func cameraLayer(_ viewModel: ScannerViewModel) -> some View {
        switch viewModel.permissionState {
        case .authorized:
            if let live = viewModel.liveProvider {
                DataScannerRepresentable(provider: live)
            } else {
                // Fixture mode: neutral backdrop standing in for the camera feed.
                Color(white: 0.12)
            }
        case .notDetermined, .denied, .restricted, .unsupported, .checking:
            permissionLayer(viewModel)
        }
    }

    @ViewBuilder
    private func permissionLayer(_ viewModel: ScannerViewModel) -> some View {
        Color.black.ignoresSafeArea()
        VStack(spacing: Tokens.Spacing.l) {
            Spacer()
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.9))
            switch viewModel.permissionState {
            case .notDetermined:
                Text(settings.localized("scanner.permission.why"))
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.85))
                Button(settings.localized("scanner.permission.allow")) {
                    viewModel.requestPermissionAndStart()
                }
                .buttonStyle(.borderedProminent)
            case .denied, .restricted:
                Text(settings.localized("scanner.permission.denied"))
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.85))
                Button(settings.localized("scanner.permission.openSettings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            case .unsupported:
                Text(settings.localized("scanner.unsupported"))
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.85))
            case .checking, .authorized:
                EmptyView()
            }
            Button(settings.localized("scanner.typeInstead")) {
                viewModel.showsManualEntry = true
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .padding(Tokens.Spacing.l)
    }

    private var focusBrackets: some View {
        GeometryReader { geo in
            let size = min(geo.size.width * 0.72, 340)
            FocusBracketsShape()
                .stroke(.white.opacity(0.55), lineWidth: 3)
                .frame(width: size, height: size * 0.62)
                .position(x: geo.size.width / 2, y: geo.size.height * 0.42)
        }
        .allowsHitTesting(false)
    }

    private func overlaysLayer(_ viewModel: ScannerViewModel) -> some View {
        ForEach(viewModel.observations) { observation in
            RecognitionOverlay(
                observation: observation,
                style: viewModel.overlayStyle(for: observation),
                onTap: { viewModel.select(observation: observation) }
            )
        }
        .animation(reduceMotion ? .none : .spring(duration: 0.25), value: viewModel.observations)
    }

    private func topControls(_ viewModel: ScannerViewModel) -> some View {
        HStack {
            FloatingIconButton(systemImage: "clock", label: settings.localized("history.title"), identifier: "historyButton") {
                showsHistory = true
            }
            Spacer()
            if viewModel.isTorchAvailable {
                FloatingIconButton(systemImage: viewModel.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill",
                                   label: settings.localized("scanner.torch"),
                                   isActive: viewModel.isTorchOn) {
                    viewModel.toggleTorch()
                }
            }
            FloatingIconButton(systemImage: "gearshape", label: settings.localized("settings.title"), identifier: "settingsButton") {
                showsSettings = true
            }
        }
        .padding(.horizontal, Tokens.Spacing.m)
        .padding(.top, Tokens.Spacing.s)
    }

    @ViewBuilder
    private func bottomBar(_ viewModel: ScannerViewModel) -> some View {
        VStack(spacing: Tokens.Spacing.s) {
            ScannerStatusCapsule(
                text: statusText(viewModel.status),
                systemImage: statusIcon(viewModel.status),
                showsActivity: viewModel.status == .searching
            )
            Button(settings.localized("scanner.typeInstead")) {
                viewModel.showsManualEntry = true
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, Tokens.Spacing.m)
            .padding(.vertical, Tokens.Spacing.xs)
            .glassControlBackground(Capsule())
            .accessibilityHint(settings.localized("scanner.typeInstead.hint"))
        }
    }

    private func statusText(_ status: ScannerViewModel.Status) -> String {
        switch status {
        case .idle, .pointAtProduct: return settings.localized("scanner.status.pointAtProduct")
        case .barcodeFound: return settings.localized("scanner.status.barcodeFound")
        case .readingLabel: return settings.localized("scanner.status.readingLabel")
        case .tapAProduct: return settings.localized("scanner.status.tapAProduct")
        case .locked: return settings.localized("scanner.status.locked")
        case .searching: return settings.localized("scanner.status.searching")
        }
    }

    private func statusIcon(_ status: ScannerViewModel.Status) -> String? {
        switch status {
        case .barcodeFound: return "barcode"
        case .readingLabel: return "text.viewfinder"
        case .tapAProduct: return "hand.tap"
        case .locked: return "checkmark"
        default: return nil
        }
    }

    // MARK: - Sheet binding

    private func sheetBinding(_ viewModel: ScannerViewModel) -> Binding<SearchSession?> {
        Binding(
            get: { viewModel.session },
            set: { newValue in
                if newValue == nil { viewModel.rescan() }
            }
        )
    }
}

private struct FocusBracketsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let arm: CGFloat = min(rect.width, rect.height) * 0.18
        // top-left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + arm))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + arm, y: rect.minY))
        // top-right
        path.move(to: CGPoint(x: rect.maxX - arm, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + arm))
        // bottom-right
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - arm))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - arm, y: rect.maxY))
        // bottom-left
        path.move(to: CGPoint(x: rect.minX + arm, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - arm))
        return path
    }
}
