import SwiftUI
import UIKit

/// The app's look in one place.
enum Theme {
    /// The single accent color. Change it here and the whole app follows: it
    /// is applied once, with `.tint`, at the root. Light mode uses a deeper
    /// amber so tinted text stays readable on white (4.6:1); dark mode uses
    /// the brighter one.
    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.69, blue: 0.13, alpha: 1) // #FFB020
            : UIColor(red: 0.70, green: 0.37, blue: 0.00, alpha: 1) // #B35F00
    })

    /// Text and symbols drawn on an accent fill (prominent buttons): white on
    /// the deep light-mode amber, near-black on the bright dark-mode one.
    static let onAccent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.08, alpha: 1)
            : .white
    })
}
