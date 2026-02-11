import SwiftUI

// MARK: - Currency Info Types

enum CurrencyInfoType: String, Identifiable {
    case hash
    case power

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hash: return L10n.Currency.hashTitle
        case .power: return L10n.Currency.powerTitle
        }
    }

    var description: String {
        switch self {
        case .hash:
            return L10n.Currency.hashDescription
        case .power:
            return L10n.Currency.powerDescription
        }
    }

    var icon: String {
        switch self {
        case .hash: return "number.circle.fill"
        case .power: return "bolt.fill"
        }
    }

    var color: Color {
        switch self {
        case .hash: return .cyan
        case .power: return .yellow
        }
    }
}
