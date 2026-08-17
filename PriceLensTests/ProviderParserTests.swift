import Foundation
import Testing
@testable import PriceLens

private func fixture(_ name: String) -> String {
    let url = Bundle(for: BundleLocator.self).url(forResource: name, withExtension: "html", subdirectory: "Providers")
        ?? Bundle(for: BundleLocator.self).url(forResource: name, withExtension: "html")
    guard let url, let html = try? String(contentsOf: url, encoding: .utf8) else {
        Issue.record("Missing fixture \(name).html")
        return ""
    }
    return html
}

private final class BundleLocator {}

@Suite("GoogleOfferHTMLParser")
struct GoogleParserTests {
    let parser = GoogleOfferHTMLParser()
    let base = URL(string: "https://www.google.pl/search?q=test&tbm=shop")!

    @Test func successFixtureYieldsOffers() {
        let (offers, diagnostics) = parser.parse(html: fixture("google_shopping_success"), baseURL: base)
        #expect(!offers.isEmpty)
        #expect(diagnostics.strategyUsed == "json-ld")
        let first = offers.first
        #expect(first?.parsedItemPrice != nil)
        #expect(first?.evidence.gtin == "5901234123457")
        #expect(offers.allSatisfy { $0.provider == .google })
    }

    @Test func noResultsFixtureYieldsEmpty() {
        let (offers, _) = parser.parse(html: fixture("google_shopping_noresults"), baseURL: base)
        #expect(offers.isEmpty)
    }

    @Test func malformedFixtureDoesNotCrash() {
        let (offers, _) = parser.parse(html: fixture("google_malformed"), baseURL: base)
        #expect(offers.isEmpty)
    }

    @Test func garbageInputDoesNotCrash() {
        let garbage = ["", "<html>", "}{[[]]}", String(repeating: "<div>", count: 500), "🛒💰 zł 999"]
        for input in garbage {
            _ = parser.parse(html: input, baseURL: base)
        }
    }
}

@Suite("AllegroOfferHTMLParser")
struct AllegroParserTests {
    let parser = AllegroOfferHTMLParser()
    let base = URL(string: "https://allegro.pl/listing?string=test")!

    @Test func successFixtureYieldsOffers() {
        let (offers, diagnostics) = parser.parse(html: fixture("allegro_listing_success"), baseURL: base)
        #expect(!offers.isEmpty)
        #expect(diagnostics.strategyUsed != nil)
        #expect(offers.allSatisfy { $0.provider == .allegro })
        #expect(offers.contains { $0.url.absoluteString.contains("/oferta/") })
        #expect(offers.allSatisfy { $0.parsedItemPrice != nil })
    }

    @Test func noResultsFixtureYieldsEmpty() {
        let (offers, _) = parser.parse(html: fixture("allegro_noresults"), baseURL: base)
        #expect(offers.isEmpty)
    }

    @Test func malformedFixtureDoesNotCrash() {
        let (offers, _) = parser.parse(html: fixture("allegro_malformed"), baseURL: base)
        #expect(offers.isEmpty)
    }

    @Test func garbageInputDoesNotCrash() {
        let garbage = ["", "<article>", "\"amount\":\"", String(repeating: "oferta/", count: 200)]
        for input in garbage {
            _ = parser.parse(html: input, baseURL: base)
        }
    }

    @Test func commaDecimalAndSpacedThousandsParse() {
        // The article-dom fixture contains "1 589,99 zł" and "1 799,00 zł"
        let (offers, _) = parser.parse(html: fixture("allegro_listing_success"), baseURL: base)
        let amounts = offers.compactMap(\.parsedItemPrice?.amount)
        #expect(amounts.contains(Decimal(string: "1589.99")!) || amounts.contains(Decimal(string: "1599.00")!))
    }
}

@Suite("PageClassifier")
struct PageClassifierTests {

    @Test func googleJSShellIsChallenge() {
        let html = fixture("google_js_shell")
        #expect(PageClassifier.classify(html: html, httpStatus: 200) == .challenge)
    }

    @Test func allegroDataDomeIsBlockedOrChallenge() {
        let html = fixture("allegro_datadome")
        let classification = PageClassifier.classify(html: html, httpStatus: 403)
        #expect(classification == .blocked)
    }

    @Test func normalPageIsContent() {
        let html = fixture("allegro_listing_success")
        #expect(PageClassifier.classify(html: html, httpStatus: 200) == .content)
    }

    @Test func status403IsBlocked() {
        #expect(PageClassifier.classify(html: "<html>ok</html>", httpStatus: 403) == .blocked)
    }
}

@Suite("StructuredDataExtractor")
struct StructuredDataExtractorTests {

    @Test func objectArrayAndGraphForms() {
        let html = """
        <html><head>
        <script type="application/ld+json">{"@type":"Product","name":"A","offers":{"@type":"Offer","price":"10.00","priceCurrency":"PLN"},"url":"https://x.pl/a"}</script>
        <script type="application/ld+json">[{"@type":"Product","name":"B","offers":{"price":"20.00","priceCurrency":"PLN"},"url":"https://x.pl/b"}]</script>
        <script type="application/ld+json">{"@graph":[{"@type":"Product","name":"C","offers":{"price":"30.00","priceCurrency":"PLN"},"url":"https://x.pl/c"}]}</script>
        </head><body></body></html>
        """
        let products = StructuredDataExtractor().extract(fromHTML: html, baseURL: URL(string: "https://x.pl")!)
        #expect(products.count == 3)
        #expect(products.compactMap(\.name).sorted() == ["A", "B", "C"])
        #expect(products.allSatisfy { $0.price != nil })
    }
}

@Suite("CeneoOfferHTMLParser")
struct CeneoParserTests {
    let parser = CeneoOfferHTMLParser()
    let base = URL(string: "https://www.ceneo.pl/szukaj-haribo+wummis")!

    @Test func successFixtureYieldsOffers() {
        let (offers, diagnostics) = parser.parse(html: fixture("ceneo_success"), baseURL: base)
        #expect(offers.count == 2)
        #expect(diagnostics.strategyUsed == "product-row")

        let first = try? #require(offers.first)
        #expect(first?.title == "Haribo Wummis Dżdżownice Żelki Owocowe 85g")
        #expect(first?.parsedItemPrice == Money(amount: 3.81, currencyCode: "PLN"))
        #expect(first?.url.absoluteString == "https://www.ceneo.pl/171393043")
        // Protocol-relative thumbnails must be resolved to https.
        #expect(first?.imageURL?.scheme == "https")
        // Ceneo does not state delivery cost: it must stay unknown, never assumed free.
        #expect(first?.parsedDeliveryPrice == nil)
    }

    /// Regression: Ceneo serves a different layout for barcode/shop searches — class
    /// `js_product-row` instead of `cat-prod-row`, and `data-GAProductName` (id-prefixed) /
    /// `data-Brand` instead of `data-productName` / `data-brand`. A class-based selector
    /// silently returned zero offers for every barcode scan.
    @Test func barcodeShopRowLayoutIsParsed() {
        let (offers, diagnostics) = parser.parse(html: fixture("ceneo_barcode_shop_row"), baseURL: base)
        #expect(diagnostics.strategyUsed == "product-row")
        #expect(offers.count == 1)
        let offer = offers.first
        #expect(offer?.title == "Regina Delicatis Chusteczki Higieniczne 96 Sztuk")
        #expect(offer?.parsedItemPrice == Money(amount: 8.72, currencyCode: "PLN"))
        #expect(offer?.url.absoluteString == "https://www.ceneo.pl/135917470")
        #expect(offer?.evidence.brand == "Regina")
        #expect(offer?.imageURL?.scheme == "https")
    }

    @Test func noResultsFixtureYieldsEmpty() {
        let (offers, _) = parser.parse(html: fixture("ceneo_no_results"), baseURL: base)
        #expect(offers.isEmpty)
    }

    @Test func malformedFixtureDoesNotCrash() {
        let (offers, _) = parser.parse(html: fixture("ceneo_malformed"), baseURL: base)
        // Empty, non-numeric and negative prices are all rejected rather than surfaced.
        #expect(offers.isEmpty)
    }

    @Test func garbageInputDoesNotCrash() {
        for garbage in ["", "<<<>>>", "{\"a\":1}", String(repeating: "<div>", count: 500)] {
            let (offers, _) = parser.parse(html: garbage, baseURL: base)
            #expect(offers.isEmpty)
        }
    }
}

@Suite("CeneoSearchURLBuilder")
struct CeneoURLTests {
    @Test func encodesPhraseAndBarcode() {
        let builder = CeneoSearchURLBuilder()
        #expect(builder.searchURL(query: "8004260487900").absoluteString
                == "https://www.ceneo.pl/szukaj-8004260487900")
        #expect(builder.searchURL(query: "haribo wummis").absoluteString
                == "https://www.ceneo.pl/szukaj-haribo+wummis")
    }
}

@Suite("CeneoWebSearchProvider")
struct CeneoProviderTests {
    let request = ProductSearchRequest(
        identity: ProductIdentity(barcode: "8004260487900", brand: nil, model: nil,
                                  titleHint: nil, rawRecognizedText: [], query: "8004260487900"),
        query: "8004260487900", countryCode: "PL", currencyCode: "PLN", preferredLanguage: "pl")

    /// Regression: Ceneo embeds a reCAPTCHA *branding* footer on ordinary result pages, so
    /// marker-based classification reported a challenge and discarded real offers. Parsed
    /// offers are direct evidence of content and must win over the heuristic.
    @Test func recaptchaBrandingDoesNotDiscardRealOffers() async {
        let html = fixture("ceneo_success")
            + "<div class=\"grecaptcha-branding\">Ta strona jest chroniona przez reCAPTCHA</div>"
        let provider = CeneoWebSearchProvider(loader: { _ in (html, 200) })
        let result = await provider.search(request)
        #expect(result.state == .success)
        #expect(result.offers.count == 2)
    }

    /// A genuine block must still be reported when nothing could be parsed.
    @Test func genuineChallengeWithNoOffersIsBlocked() async {
        let provider = CeneoWebSearchProvider(loader: { _ in
            (String(repeating: "<p>Please enable JS and disable any ad blocker</p>", count: 20), 200)
        })
        let result = await provider.search(request)
        #expect(result.state == .blocked)
        #expect(result.offers.isEmpty)
    }

    @Test func offlineIsReportedNotFabricated() async {
        let provider = CeneoWebSearchProvider(loader: { _ in throw HTTPError.offline })
        let result = await provider.search(request)
        #expect(result.state == .offline)
        #expect(result.offers.isEmpty)
    }
}
