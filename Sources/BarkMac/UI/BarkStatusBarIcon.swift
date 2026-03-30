import AppKit

enum BarkStatusBarIcon {
    static func makeImage() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            drawIcon(in: rect)
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func drawIcon(in rect: NSRect) {
        let strokeColor = NSColor.labelColor
        strokeColor.setStroke()

        let leftBody = NSBezierPath()
        leftBody.lineWidth = 1.65
        leftBody.lineJoinStyle = .round
        leftBody.lineCapStyle = .round
        leftBody.move(to: point(4.3, 5.35, in: rect))
        leftBody.line(to: point(2.35, 6.35, in: rect))
        leftBody.line(to: point(2.35, 11.65, in: rect))
        leftBody.line(to: point(4.3, 12.65, in: rect))
        leftBody.line(to: point(6.85, 11.9, in: rect))
        leftBody.line(to: point(6.85, 6.1, in: rect))
        leftBody.close()
        leftBody.stroke()

        let bridge = NSBezierPath(roundedRect: scaledRect(x: 7.55, y: 7.25, width: 2.9, height: 3.5, in: rect), xRadius: 0.75, yRadius: 0.75)
        bridge.lineWidth = 1.65
        bridge.lineJoinStyle = .round
        bridge.lineCapStyle = .round
        bridge.stroke()

        let rightBody = NSBezierPath()
        rightBody.lineWidth = 1.65
        rightBody.lineJoinStyle = .round
        rightBody.lineCapStyle = .round
        rightBody.move(to: point(13.7, 5.35, in: rect))
        rightBody.line(to: point(15.65, 6.35, in: rect))
        rightBody.line(to: point(15.65, 11.65, in: rect))
        rightBody.line(to: point(13.7, 12.65, in: rect))
        rightBody.line(to: point(11.15, 11.9, in: rect))
        rightBody.line(to: point(11.15, 6.1, in: rect))
        rightBody.close()
        rightBody.stroke()
    }

    private static func point(_ x: CGFloat, _ y: CGFloat, in rect: NSRect) -> NSPoint {
        let sx = rect.minX + (x / 18.0) * rect.width
        let sy = rect.minY + (y / 18.0) * rect.height
        return NSPoint(x: sx, y: sy)
    }

    private static func scaledRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, in rect: NSRect) -> NSRect {
        NSRect(
            x: rect.minX + (x / 18.0) * rect.width,
            y: rect.minY + (y / 18.0) * rect.height,
            width: (width / 18.0) * rect.width,
            height: (height / 18.0) * rect.height
        )
    }
}
