import AppKit
import ShapeKit

final class Ink {
    let layer = CALayer()
    var keep: Bool { Preferences.fadeSeconds <= 0 }

    static let purple = CGColor(srgbRed: 0.53, green: 0.33, blue: 0.95, alpha: 1)
    static let red = CGColor(srgbRed: 1.0, green: 0.16, blue: 0.12, alpha: 1)

    static func hex(_ v: UInt32) -> CGColor {
        CGColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }
    var color = Ink.purple
    var scale: CGFloat = 2
    private var fadeDelay: CFTimeInterval { max(0.5, Preferences.fadeSeconds) }
    private let fadeDuration: CFTimeInterval = 0.6

    private var stroke: CAShapeLayer?
    private var points: [CGPoint] = []
    private var lastLine: (layer: CAShapeLayer, shape: th_shape, at: Date)?
    private var fades = 0

    var isDrawing: Bool { stroke != nil }

    init() {
        layer.masksToBounds = false
    }

    func begin(at point: CGPoint, width: CGFloat) {
        let s = CAShapeLayer()
        s.strokeColor = color
        s.fillColor = nil
        s.lineWidth = width
        s.lineCap = .round
        s.lineJoin = .round
        s.shadowColor = NSColor.black.cgColor
        s.shadowOpacity = 0.18
        s.shadowRadius = 1.5
        s.shadowOffset = CGSize(width: 1, height: -1.5)
        layer.addSublayer(s)
        stroke = s
        points = [point]
        redraw()
    }

    func extend(to point: CGPoint) {
        guard stroke != nil, let last = points.last else {
            return
        }
        if hypot(point.x - last.x, point.y - last.y) < 1.5 {
            return
        }
        points.append(point)
        redraw()
    }

    func end() {
        guard let s = stroke else {
            return
        }
        let drawn = points
        stroke = nil
        points = []
        if Preferences.snapShapes {
            if snapArrowhead(drawn, stroke: s) {
                return
            }
            snap(drawn, stroke: s)
        } else {
            lastLine = nil
        }
        freeze(s)
        if keep {
            return
        }
        fade(s, after: fadeDelay, over: fadeDuration)
    }

    func clear() {
        stroke = nil
        points = []
        lastLine = nil
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }
    }

    private func snap(_ drawn: [CGPoint], stroke s: CAShapeLayer) {
        lastLine = nil
        let input = drawn.map { th_point(x: Float($0.x), y: Float($0.y)) }
        var shape = th_shape()
        let kind = th_recognize(input, Int32(input.count), 0, &shape)
        guard kind != TH_SHAPE_NONE else {
            return
        }
        show(shape, in: s)
        Log.write("snapped stroke to \(String(cString: th_shape_name(kind)))")
        if kind == TH_SHAPE_LINE {
            lastLine = (s, shape, Date())
        }
    }

    private func snapArrowhead(_ drawn: [CGPoint], stroke s: CAShapeLayer) -> Bool {
        guard let last = lastLine, Date().timeIntervalSince(last.at) < 3, last.layer.superlayer != nil,
              last.layer.strokeColor == s.strokeColor else {
            return false
        }
        let input = drawn.map { th_point(x: Float($0.x), y: Float($0.y)) }
        var line = last.shape
        var arrow = th_shape()
        guard th_recognize_arrowhead(&line, input, Int32(input.count), 0, &arrow) == TH_SHAPE_ARROW else {
            return false
        }
        lastLine = nil
        s.removeFromSuperlayer()
        show(arrow, in: last.layer)
        freeze(last.layer)
        if !keep {
            fade(last.layer, after: fadeDelay, over: fadeDuration)
        }
        Log.write("snapped arrowhead onto line")
        return true
    }

    private func show(_ shape: th_shape, in s: CAShapeLayer) {
        var shape = shape
        let path = CGMutablePath()
        for i in 0..<th_shape_path_count(&shape) {
            let start = th_shape_path_start(&shape, i)
            let count = th_shape_path_length(&shape, i)
            guard count > 1 else {
                continue
            }
            let pts = (0..<count).map { j -> CGPoint in
                let p = th_shape_point(&shape, start + j)
                return CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))
            }
            path.addLines(between: pts)
            if th_shape_path_closed(&shape, i) != 0 {
                path.closeSubpath()
            }
        }
        let crossfade = CATransition()
        crossfade.type = .fade
        crossfade.duration = 0.12
        s.add(crossfade, forKey: "snap")
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        s.path = path
        CATransaction.commit()
    }

    private func freeze(_ s: CAShapeLayer) {
        guard let path = s.path else {
            return
        }
        let pad = s.lineWidth / 2 + s.shadowRadius * 3 + max(abs(s.shadowOffset.width), abs(s.shadowOffset.height)) + 2
        let box = path.boundingBoxOfPath.insetBy(dx: -pad, dy: -pad).integral
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        s.bounds = box
        s.position = CGPoint(x: box.midX, y: box.midY)
        s.rasterizationScale = scale
        s.shouldRasterize = true
        CATransaction.commit()
    }

    private func fade(_ s: CAShapeLayer, after delay: CFTimeInterval, over duration: CFTimeInterval) {
        fades += 1
        let token = fades
        s.setValue(token, forKey: "fadeToken")
        s.removeAnimation(forKey: "fade")
        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = 1
        anim.toValue = 0
        anim.beginTime = CACurrentMediaTime() + delay
        anim.duration = duration
        anim.timingFunction = CAMediaTimingFunction(name: .easeIn)
        anim.fillMode = .forwards
        anim.isRemovedOnCompletion = false
        s.add(anim, forKey: "fade")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + duration) { [weak s] in
            guard let s = s, s.value(forKey: "fadeToken") as? Int == token else {
                return
            }
            s.removeFromSuperlayer()
        }
    }

    private func redraw() {
        guard let s = stroke, let first = points.first else {
            return
        }
        let path = CGMutablePath()
        path.move(to: first)
        if points.count == 1 {
            path.addLine(to: first)
        }
        for i in 1..<max(1, points.count) {
            let p = points[i]
            let prev = points[i - 1]
            let mid = CGPoint(x: (prev.x + p.x) / 2, y: (prev.y + p.y) / 2)
            path.addQuadCurve(to: mid, control: prev)
        }
        if points.count > 1, let last = points.last {
            path.addLine(to: last)
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        s.path = path
        CATransaction.commit()
    }
}
