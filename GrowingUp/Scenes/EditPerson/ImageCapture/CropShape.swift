//
//  CropShape.swift
//  GrowingUp
//
//  The crop geometry for a person-image slot. Describes the two fixed slots
//  (main picture, widget picture) for the in-app cropper.
//

import CoreGraphics

enum CropShape {
    /// Main app picture — portrait rectangle.
    case rectangle
    /// Widget picture — circular avatar.
    case circle

    /// True when the crop window should be drawn as a circular guide. The
    /// persisted image is still a square (see `cropCircular`); the circle is a
    /// display-time aid only.
    var isCircular: Bool {
        switch self {
        case .rectangle: return false
        case .circle:    return true
        }
    }

    /// Width / height for the rectangle mask. Ignored for `.circle`.
    /// Portrait 4:5, sized to fill the full-bleed main picture under aspectFill.
    var aspectRatio: CGFloat {
        switch self {
        case .rectangle: return 4.0 / 5.0
        case .circle:    return 1
        }
    }

    /// Always false: both slots persist opaque, non-circular images. The widget's
    /// circle is applied as a display-time mask, so the stored file is a full square —
    /// this avoids JPEG encoding flattening a transparent circular PNG's corners to black.
    var cropCircular: Bool { false }

    /// Longest-side target, in pixels, for the persisted image. Downscale only —
    /// the main picture is shown full-screen (~1800px is ample at 3x), the widget
    /// picture never exceeds ~56pt (480px covers Retina with headroom).
    var maxPixelSize: CGFloat {
        switch self {
        case .rectangle: return 1800
        case .circle:    return 480
        }
    }
}
