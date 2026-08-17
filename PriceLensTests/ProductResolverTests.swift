import Foundation
import Testing
@testable import PriceLens

@Suite("ResolvedProduct")
struct ResolvedProductTests {

    @Test func combinesBrandAndName() {
        let product = ResolvedProduct(barcode: "5996379357362", name: "Wummis", brand: "Haribo", imageURL: nil)
        #expect(product.displayTitle == "Haribo Wummis")
    }

    /// Avoids "Haribo Haribo Wummis" when the product name already carries the brand.
    @Test func doesNotRepeatBrandAlreadyInName() {
        let product = ResolvedProduct(barcode: "1", name: "Haribo Wummis", brand: "Haribo", imageURL: nil)
        #expect(product.displayTitle == "Haribo Wummis")
    }

    @Test func nameOnlyAndBrandOnly() {
        #expect(ResolvedProduct(barcode: "1", name: "Wummis", brand: nil, imageURL: nil).displayTitle == "Wummis")
        #expect(ResolvedProduct(barcode: "1", name: nil, brand: "Haribo", imageURL: nil).displayTitle == "Haribo")
    }

    /// A lookup that yields no usable text must be treated as "unknown", never fabricated.
    @Test func emptyProductHasNoTitle() {
        #expect(ResolvedProduct(barcode: "1", name: nil, brand: nil, imageURL: nil).displayTitle == nil)
    }
}
