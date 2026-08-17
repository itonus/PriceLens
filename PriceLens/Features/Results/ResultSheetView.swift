import SwiftUI
import SafariServices

/// Result bottom sheet over the camera: decision first, offers second.
struct ResultSheetView: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    /// Used for the Allegro hand-off: an in-app Safari view cannot pass a universal link to
    /// the installed Allegro app, but `openURL` can.
    @Environment(\.openURL) private var openURL

    let viewModel: ResultsViewModel
    @State private var safariURL: URL?
    @State private var isEditing = false
    @State private var editQuery: String = ""
    @State private var editPrice: String = ""
    @State private var selectedDetent: PresentationDetent = .height(340)

    init(viewModel: ResultsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        content(viewModel)
        .presentationDetents([.height(340), .medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled(upThrough: .height(340)))
        .interactiveDismissDisabled(false)
        .onAppear { viewModel.begin() }
        .onDisappear { viewModel.stop() }
        .sheet(item: $safariURL) { url in
            SafariView(url: url)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ vm: ResultsViewModel) -> some View {
        NavigationStack {
            ScrollView {
                // One continuous list: verdict first, then the offer cards. There is no
                // "view offers" step — the offers are the content, so they are always present
                // and simply scroll into view as the sheet is dragged up.
                VStack(alignment: .leading, spacing: Tokens.Spacing.m) {
                    peekContent(vm)
                    expandedContent(vm)
                }
                .padding(.horizontal, Tokens.Spacing.m)
                .padding(.bottom, Tokens.Spacing.l)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(settings.localized("results.rescan")) {
                        dismiss()
                    }
                    .accessibilityHint(settings.localized("results.rescan.hint"))
                    .accessibilityIdentifier("rescanButton")
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Peek: the purchase answer first

    @ViewBuilder
    private func peekContent(_ vm: ResultsViewModel) -> some View {
        // Product identity — shows the confirmed product (name + image) once the barcode
        // has been resolved, otherwise whatever the scanner derived.
        HStack(alignment: .top, spacing: Tokens.Spacing.s) {
            if let imageURL = vm.resolvedProduct?.imageURL {
                OfferThumbnail(url: imageURL, size: 56)
            }
            VStack(alignment: .leading, spacing: Tokens.Spacing.xxs) {
                Text(vm.resolvedProduct?.displayTitle ?? vm.identity.query)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text(identitySubtitle(vm))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        // Provider chips
        HStack(spacing: Tokens.Spacing.xs) {
            ForEach(vm.enabledProviders) { provider in
                let status = vm.providerStatus[provider]
                ProviderStatusChip(provider: provider,
                                   state: status?.state,
                                   offerCount: status?.offerCount ?? 0,
                                   isSearching: status?.isSearching ?? true)
            }
        }

        // Numbers
        HStack(alignment: .top, spacing: Tokens.Spacing.m) {
            VStack(alignment: .leading) {
                Text(settings.localized("results.storePrice"))
                    .font(.caption).foregroundStyle(.secondary)
                if let storePrice = vm.storePrice {
                    PriceValueView(money: storePrice, font: .title3.weight(.semibold))
                } else {
                    Button(settings.localized("results.addStorePrice")) { beginEditing(vm) }
                        .font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("addStorePriceButton")
                }
            }
            Spacer()
            VStack(alignment: .leading) {
                Text(settings.localized("results.bestOnline"))
                    .font(.caption).foregroundStyle(.secondary)
                PriceValueView(money: vm.decision.bestOffer?.comparisonPrice,
                               font: .title3.weight(.semibold))
            }
            if let saving = vm.decision.absoluteSaving, let percent = vm.decision.percentSaving {
                Spacer()
                VStack(alignment: .leading) {
                    Text(settings.localized("results.save"))
                        .font(.caption).foregroundStyle(.secondary)
                    Text("\(MoneyFormatter.string(saving, locale: settings.activeLocale)) · \(MoneyFormatter.percent(percent, locale: settings.activeLocale))")
                        .font(.headline)
                        .foregroundStyle(.green)
                        .contentTransition(.numericText())
                }
            }
        }

        // Recommendation
        if let recommendation = vm.decision.recommendation {
            DecisionBadge(recommendation: recommendation, prominent: true)
                .accessibilityIdentifier("decisionBadge")
        } else if vm.isFinished && !vm.offers.isEmpty {
            DecisionBadge(recommendation: .compareCarefully, prominent: true)
                .accessibilityIdentifier("decisionBadge")
        }

        HStack(spacing: Tokens.Spacing.m) {
            // Correcting the query is a recovery path, not a primary action: keep it available
            // but quiet, so the verdict and the offers stay the focus.
            Button(settings.localized("action.edit")) { beginEditing(vm) }
                .accessibilityIdentifier("editButton")

            Spacer()

            Button {
                openURL(allegroSearchURL(vm))
            } label: {
                Label(settings.localized("results.openAllegro"), systemImage: "arrow.up.forward.app")
            }
            .accessibilityIdentifier("openAllegroButton")
        }
        .font(.subheadline)
    }

    /// Allegro search as a universal link: iOS hands this to the Allegro app when installed and
    /// falls back to the browser otherwise. Must be opened with `openURL`, not an in-app Safari
    /// view, or the hand-off never happens.
    private func allegroSearchURL(_ vm: ResultsViewModel) -> URL {
        let phrase = vm.resolvedProduct?.displayTitle ?? vm.identity.query
        let query = phrase.isEmpty ? (vm.identity.barcode ?? "") : phrase
        return AllegroSearchURLBuilder().searchURL(query: query)
    }

    // MARK: - Expanded: offers, editing, fallbacks

    @ViewBuilder
    private func expandedContent(_ vm: ResultsViewModel) -> some View {
        // Editing
        if isEditing {
            editingCard(vm)
        }

        // Sort + offers
        if !vm.offers.isEmpty {
            HStack {
                Text(settings.localized("results.offers"))
                    .font(.headline)
                Spacer()
                Menu(settings.localized(sortKey(vm.sortOrder))) {
                    ForEach(OfferSortOrder.allCases, id: \.self) { order in
                        Button(settings.localized(sortKey(order))) { vm.changeSortOrder(order) }
                    }
                }
                .font(.subheadline)
                .accessibilityIdentifier("sortMenu")
            }

            LazyVStack(spacing: Tokens.Spacing.s) {
                ForEach(vm.offers) { offer in
                    OfferCard(offer: offer, onOpen: { safariURL = offer.productURL })
                        .transition(.opacity)
                        .accessibilityIdentifier("offerCard_\(offer.provider.rawValue)")
                }
            }
            .animation(.spring(duration: 0.3), value: vm.offers)
        } else if vm.isFinished {
            EmptyState(systemImage: "magnifyingglass",
                       title: settings.localized("results.noOffers"),
                       message: settings.localized("results.noOffers.hint"))
        }

        if vm.isFinished {
            fallbackArea(vm)
        }
    }

    @ViewBuilder
    private func editingCard(_ vm: ResultsViewModel) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.s) {
            TextField(settings.localized("results.queryPlaceholder"), text: $editQuery)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("editQueryField")
            HStack {
                TextField(settings.localized("results.pricePlaceholder"), text: $editPrice)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("editPriceField")
                Button(settings.localized("action.apply")) {
                    vm.updateQuery(editQuery)
                    if let price = PriceParser.parse(editPrice) {
                        vm.updateStorePrice(price)
                    }
                    isEditing = false
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("applyEditButton")
            }
        }
        .padding(Tokens.Spacing.s)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Tokens.Corner.card))
    }

    /// One-tap provider fallbacks when extraction failed.
    @ViewBuilder
    private func fallbackArea(_ vm: ResultsViewModel) -> some View {
        ForEach(vm.enabledProviders) { provider in
            if let status = vm.providerStatus[provider],
               let state = status.state,
               [.fallbackOnly, .blocked, .failed, .offline].contains(state),
               let url = status.searchURL {
                InlineErrorState(
                    message: fallbackMessage(provider: provider, state: state),
                    openTitle: fallbackOpenTitle(provider),
                    onOpen: { safariURL = url },
                    retryTitle: state == .offline || state == .failed ? settings.localized("action.retry") : nil,
                    onRetry: state == .offline || state == .failed ? { vm.retry() } : nil
                )
                .accessibilityIdentifier("fallback_\(provider.rawValue)")
            }
        }
    }

    // MARK: - Helpers

    private func beginEditing(_ vm: ResultsViewModel) {
        editQuery = vm.identity.query
        editPrice = vm.storePrice.map { "\($0.amount)" } ?? ""
        isEditing = true
        selectedDetent = .large
    }

    private func identitySubtitle(_ vm: ResultsViewModel) -> String {
        if vm.identity.barcode != nil { return settings.localized("identity.barcode") }
        if vm.identity.model != nil { return settings.localized("identity.likelyModel") }
        return settings.localized("identity.textSearch")
    }

    /// "Open <provider> results". Ceneo has no dedicated string yet, so it uses the generic
    /// format rather than showing an untranslated key.
    private func fallbackOpenTitle(_ provider: SearchProviderID) -> String {
        switch provider {
        case .google: return settings.localized("fallback.openGoogle")
        case .allegro: return settings.localized("fallback.openAllegro")
        case .ceneo:
            return String(format: settings.localized("fallback.openProvider"), provider.displayName)
        }
    }

    private func fallbackMessage(provider: SearchProviderID, state: ProviderSearchState) -> String {
        switch state {
        case .blocked:
            return String(format: settings.localized("fallback.blocked"), provider.displayName)
        case .offline:
            return settings.localized("scanner.status.offline")
        case .failed, .fallbackOnly:
            return String(format: settings.localized("fallback.unreadable"), provider.displayName)
        default:
            return ""
        }
    }

    private func sortKey(_ order: OfferSortOrder) -> String {
        switch order {
        case .bestMatch: return "sort.bestMatch"
        case .lowestItemPrice: return "sort.lowestItemPrice"
        case .lowestTotal: return "sort.lowestTotal"
        }
    }
}

/// In-app Safari.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
