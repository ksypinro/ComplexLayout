//
//  UIColor+Hex.swift
//  ComplexLayout
//

import UIKit

extension UIColor {
    /// Creates a color from a 24-bit RGB literal, e.g. `UIColor(hex: 0x5B5BD6)`.
    nonisolated convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex & 0xFF0000) >> 16) / 255,
            green: CGFloat((hex & 0x00FF00) >> 8) / 255,
            blue: CGFloat(hex & 0x0000FF) / 255,
            alpha: alpha
        )
    }
}
