import UIKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
                  blue: CGFloat(hex & 255) / 255, alpha: alpha)
    }
}

enum Palette {
    static let ink = UIColor(hex: 0x13164D)
    static let yellow = UIColor(hex: 0xFFE742)
    static let cyan = UIColor(hex: 0x51E7FF)
    static let quiet = UIColor(hex: 0xACB9F4)
    static let panel = UIColor(hex: 0x17257E)
    static let green = UIColor(hex: 0x9EF14A)
    static func font(_ size: CGFloat, _ weight: UIFont.Weight = .bold) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        return UIFont(descriptor: base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor, size: size)
    }
}

extension CardKind {
    var tint: UIColor {
        switch self {
        case .seed, .oak: return UIColor(hex: 0xACF34B)
        case .dragon, .elder: return UIColor(hex: 0xFFAE50)
        case .shield: return UIColor(hex: 0x36DFFF)
        case .rewind: return UIColor(hex: 0xE47FFF)
        case .spark: return UIColor(hex: 0xFFE047)
        case .surge: return UIColor(hex: 0xAA86FF)
        case .guardian: return UIColor(hex: 0xFF8B8E)
        }
    }
    var symbol: String {
        switch self {
        case .seed, .oak: return "leaf.fill"
        case .dragon, .elder: return "sparkles"
        case .shield, .guardian: return "shield.fill"
        case .rewind: return "backward.fill"
        case .spark: return "bolt.fill"
        case .surge: return "cloud.bolt.fill"
        }
    }
}

extension TimeLane {
    var tint: UIColor { [Palette.cyan, UIColor(hex: 0xFF9B59), UIColor(hex: 0xDA89FF)][rawValue] }
}

enum GameArt {
    private static var cached: [Int: UIImage] = [:]
    static func image(_ index: Int) -> UIImage? {
        if let existing = cached[index] { return existing }
        // 0–8: cards, 9–14: enemies; the storm has a standalone illustration.
        if index == 15 {
            let image = UIImage(named: "EnergyStorm")
            cached[index] = image
            return image
        }
        let enemy = index >= 9
        let tile = enemy ? index - 9 : index
        guard let atlas = UIImage(named: enemy ? "EnemyAtlas" : "CardAtlas")?.cgImage else { return nil }
        let cellW = CGFloat(atlas.width) / 3, cellH = CGFloat(atlas.height) / (enemy ? 2 : 3)
        let cell = CGRect(x: CGFloat(tile % 3) * cellW, y: CGFloat(tile / 3) * cellH, width: cellW, height: cellH)
        guard let cg = atlas.cropping(to: cell.integral) else { return nil }
        let image = UIImage(cgImage: cg)
        cached[index] = image
        return image
    }
}

@discardableResult
func gameLabel(_ text: String, size: CGFloat, color: UIColor = .white, weight: UIFont.Weight = .bold,
               alignment: NSTextAlignment = .left) -> UILabel {
    let label = UILabel()
    label.text = text
    label.textColor = color
    label.font = Palette.font(size, weight)
    label.textAlignment = alignment
    label.adjustsFontSizeToFitWidth = true
    label.minimumScaleFactor = 0.8
    return label
}

final class OutlinedLabel: UILabel {
    var outline = Palette.ink
    var outlineWidth: CGFloat = 7
    override func drawText(in rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let original = textColor
        context.saveGState()
        context.setLineWidth(outlineWidth)
        context.setLineJoin(.round)
        context.setTextDrawingMode(.stroke)
        textColor = outline
        super.drawText(in: rect)
        context.setTextDrawingMode(.fill)
        textColor = original
        super.drawText(in: rect)
        context.restoreGState()
    }
}

final class GameBackdrop: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = UIColor(hex: 0x11154E)
        contentMode = .redraw
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() { super.layoutSubviews(); setNeedsDisplay() }
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let w = bounds.width, h = bounds.height
        let colors = [UIColor(hex: 0x2241B7).cgColor, UIColor(hex: 0x191779).cgColor, UIColor(hex: 0x090E3D).cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.48, 1]) {
            context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: h), options: [])
        }
        // Decorative gear silhouettes and tiny stars are native vector artwork.
        for i in 0..<9 {
            let cx = CGFloat((i * 83 + 22) % 390) / 390 * w
            let cy = CGFloat((i * 131 + 86) % 780) / 780 * h
            let radius: CGFloat = CGFloat(21 + i % 4 * 12)
            context.saveGState()
            context.translateBy(x: cx, y: cy)
            context.rotate(by: CGFloat(i) * 0.37)
            context.setFillColor(UIColor(hex: 0x55A7EF, alpha: 0.065).cgColor)
            for tooth in 0..<8 {
                context.saveGState()
                context.rotate(by: CGFloat(tooth) * .pi / 4)
                context.fill(CGRect(x: -radius * 0.18, y: -radius * 1.15, width: radius * 0.36, height: radius * 0.45))
                context.restoreGState()
            }
            let ring = UIBezierPath(ovalIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
            ring.append(UIBezierPath(ovalIn: CGRect(x: -radius * 0.45, y: -radius * 0.45, width: radius * 0.9, height: radius * 0.9)))
            ring.usesEvenOddFillRule = true
            UIColor(hex: 0x55A7EF, alpha: 0.065).setFill(); ring.fill()
            context.restoreGState()
        }
        for i in 0..<27 {
            let x = CGFloat((i * 97 + 17) % 390) / 390 * w
            let y = CGFloat((i * 61 + 9) % 844) / 844 * h
            let r: CGFloat = i % 5 == 0 ? 2 : 1
            UIColor.white.withAlphaComponent(i % 3 == 0 ? 0.24 : 0.1).setFill()
            UIBezierPath(ovalIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)).fill()
        }
    }
}

final class GameButton: UIButton {
    private let fill = CAGradientLayer()
    private let glyph = UIImageView()
    var onTap: (() -> Void)?
    init(_ title: String, primary: Bool = false, symbol: String? = nil) {
        super.init(frame: .zero)
        setTitle(title, for: .normal)
        titleLabel?.font = Palette.font(primary ? 23 : 15, .heavy)
        setTitleColor(primary ? Palette.ink : .white, for: .normal)
        layer.cornerRadius = primary ? 25 : 15
        layer.borderWidth = primary ? 3 : 1.5
        layer.borderColor = (primary ? UIColor(hex: 0xFFF68B) : UIColor(hex: 0x657DD6)).cgColor
        layer.shadowColor = UIColor(hex: primary ? 0xD78A08 : 0x030B36).cgColor
        layer.shadowOpacity = 1
        layer.shadowOffset = CGSize(width: 0, height: primary ? 5 : 3)
        layer.shadowRadius = 0
        fill.colors = primary ? [UIColor(hex: 0xFFF76C).cgColor, UIColor(hex: 0xFFCF20).cgColor] :
            [UIColor(hex: 0x314EAA).cgColor, UIColor(hex: 0x243987).cgColor]
        layer.insertSublayer(fill, at: 0)
        if let symbol = symbol {
            glyph.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: primary ? 22 : 17, weight: .bold))
            glyph.tintColor = primary ? Palette.ink : .white
            glyph.contentMode = .scaleAspectFit
            glyph.isUserInteractionEnabled = false
            addSubview(glyph)
        }
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.78 : 1 } }
    override var isEnabled: Bool { didSet { alpha = isEnabled ? 1 : 0.45 } }
    override func layoutSubviews() {
        super.layoutSubviews()
        fill.frame = bounds
        fill.cornerRadius = layer.cornerRadius
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath
        if let titleLabel = titleLabel { bringSubviewToFront(titleLabel) }
        if glyph.image != nil {
            let side: CGFloat = bounds.height > 50 ? 24 : 20
            let textWidth = min(titleLabel?.intrinsicContentSize.width ?? 0, bounds.width - side - 26)
            let hasTitle = !(title(for: .normal) ?? "").isEmpty
            let start = (bounds.width - (hasTitle ? textWidth + side + 10 : side)) / 2
            glyph.frame = CGRect(x: start, y: (bounds.height - side) / 2, width: side, height: side)
            if hasTitle { titleLabel?.frame = CGRect(x: start + side + 10, y: 0, width: textWidth, height: bounds.height) }
            bringSubviewToFront(glyph)
        }
    }
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.insetBy(dx: min(0, (bounds.width - 44) / 2), dy: min(0, (bounds.height - 44) / 2)).contains(point)
    }
    @objc private func tapped() { onTap?() }
}

final class GamePanel: UIView {
    init(color: UIColor = Palette.panel, border: UIColor = UIColor(hex: 0x4A65C8)) {
        super.init(frame: .zero)
        backgroundColor = color.withAlphaComponent(0.92)
        layer.cornerRadius = 18
        layer.borderColor = border.withAlphaComponent(0.8).cgColor
        layer.borderWidth = 1.5
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class CostBadge: UIView {
    var number: Int = 0 { didSet { label.text = "\(number)" } }
    private let label = OutlinedLabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        label.textAlignment = .center; label.font = Palette.font(22, .black)
        label.textColor = .white; label.outlineWidth = 3
        addSubview(label)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() { super.layoutSubviews(); label.frame = bounds.insetBy(dx: 3, dy: 2); setNeedsDisplay() }
    override func draw(_ rect: CGRect) {
        let p = UIBezierPath()
        let w = bounds.width, h = bounds.height
        p.move(to: CGPoint(x: w / 2, y: 1))
        p.addLine(to: CGPoint(x: w - 2, y: h * 0.23)); p.addLine(to: CGPoint(x: w - 2, y: h * 0.77))
        p.addLine(to: CGPoint(x: w / 2, y: h - 1)); p.addLine(to: CGPoint(x: 2, y: h * 0.77))
        p.addLine(to: CGPoint(x: 2, y: h * 0.23)); p.close()
        UIColor(hex: 0x0A93E9).setFill(); p.fill()
        UIColor(hex: 0xC0F9FF).setStroke(); p.lineWidth = 2; p.stroke()
    }
}

final class CardView: UIControl {
    let kind: CardKind
    private let artView = UIImageView()
    private let title = UILabel()
    private let effect = UILabel()
    private let footer = UIView()
    private let badge = CostBadge()
    private let stat = UILabel()
    private let icon = UIImageView()
    private let gradient = CAGradientLayer()
    var onTap: (() -> Void)?
    var selectedCard = false { didSet { updateSelection() } }
    var locked = false { didSet { alpha = locked ? 0.43 : 1 } }
    var fieldCard: FieldCard? { didSet { configure() } }
    var titleOverride: String? { didSet { configure() } }
    init(_ kind: CardKind) {
        self.kind = kind
        super.init(frame: .zero)
        layer.cornerRadius = 12
        layer.borderWidth = 2.5
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 3
        layer.shadowOpacity = 0.35
        layer.insertSublayer(gradient, at: 0)
        gradient.colors = [kind.tint.cgColor, kind.tint.withAlphaComponent(0.72).cgColor]
        artView.contentMode = .scaleAspectFill
        artView.clipsToBounds = true
        artView.layer.cornerRadius = 7
        artView.isUserInteractionEnabled = false
        addSubview(artView)
        footer.backgroundColor = UIColor.white.withAlphaComponent(0.91)
        footer.layer.cornerRadius = 5
        addSubview(footer)
        title.font = Palette.font(14, .heavy); title.textColor = Palette.ink
        title.textAlignment = .center; title.adjustsFontSizeToFitWidth = true; title.minimumScaleFactor = 0.75
        title.numberOfLines = 2
        effect.font = Palette.font(10, .bold); effect.textColor = Palette.ink
        effect.adjustsFontSizeToFitWidth = true; effect.minimumScaleFactor = 0.85
        icon.tintColor = Palette.ink; icon.contentMode = .scaleAspectFit
        stat.font = Palette.font(14, .black); stat.textColor = .white
        stat.textAlignment = .center; stat.backgroundColor = UIColor(hex: 0xF25B79)
        stat.layer.cornerRadius = 10; stat.clipsToBounds = true
        footer.addSubview(title); footer.addSubview(effect); footer.addSubview(icon); footer.addSubview(stat)
        addSubview(badge)
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
        isAccessibilityElement = true
        accessibilityTraits = .button
        configure(); updateSelection()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    var onDrop: ((CGPoint) -> Void)?
    private var dragOrigin: CGPoint?
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        dragOrigin = touches.first?.location(in: window)
        super.touchesBegan(touches, with: event)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer { dragOrigin = nil }
        if let start = dragOrigin, let end = touches.first?.location(in: window),
           hypot(end.x - start.x, end.y - start.y) > 16, let onDrop = onDrop {
            // Accessibility pointers may deliver just the endpoints of a drag.
            // Normal pans cancel these control touches, so this cannot double-play.
            super.touchesCancelled(touches, with: event)
            onDrop(end)
        } else { super.touchesEnded(touches, with: event) }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        dragOrigin = nil
        super.touchesCancelled(touches, with: event)
    }
    private func configure() {
        artView.image = GameArt.image(fieldCard?.art ?? kind.art)
        title.text = titleOverride ?? fieldCard?.name ?? kind.name
        effect.text = fieldCard?.waiting == true ? "Waiting" : fieldCard?.evolved == true ? "Grown" : kind.keyword
        stat.text = "\(fieldCard?.attack ?? kind.attack)"
        stat.isHidden = !kind.isUnit
        icon.image = UIImage(systemName: kind.symbol)
        badge.number = kind.cost
        accessibilityLabel = "\(title.text ?? kind.name), \(kind.cost) energy, \(kind.keyword)"
        accessibilityHint = "Tap to select. Hold for details."
    }
    private func updateSelection() {
        layer.borderColor = (selectedCard ? UIColor.white : kind.tint).cgColor
        layer.borderWidth = selectedCard ? 3.5 : 2.5
        layer.shadowColor = (selectedCard ? Palette.cyan : UIColor.black).cgColor
        layer.shadowRadius = selectedCard ? 10 : 3
        layer.shadowOpacity = selectedCard ? 0.9 : 0.35
        accessibilityTraits = selectedCard ? [.button, .selected] : .button
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds; gradient.cornerRadius = 12
        let pad: CGFloat = 5, footerH: CGFloat = min(58, max(43, bounds.height * 0.36))
        artView.frame = CGRect(x: pad, y: pad, width: bounds.width - pad * 2, height: bounds.height - footerH - pad * 2)
        footer.frame = CGRect(x: pad, y: bounds.height - footerH - pad, width: bounds.width - pad * 2, height: footerH)
        title.font = Palette.font(max(10, min(14, bounds.width * 0.13)), .heavy)
        title.frame = CGRect(x: 2, y: 1, width: footer.bounds.width - 4, height: footerH * 0.59)
        let narrow = bounds.width < 90
        icon.isHidden = narrow
        icon.frame = CGRect(x: 4, y: footerH * 0.65, width: 11, height: 11)
        let effectX: CGFloat = narrow ? 4 : 18
        effect.frame = CGRect(x: effectX, y: footerH * 0.61, width: max(20, footer.bounds.width - effectX - (kind.isUnit ? 25 : 3)), height: footerH * 0.36)
        stat.font = Palette.font(narrow ? 11 : 13, .black)
        stat.frame = CGRect(x: footer.bounds.width - 22, y: footerH * 0.62, width: 19, height: min(19, footerH * 0.36))
        badge.frame = CGRect(x: 0, y: 0, width: min(31, bounds.width * 0.29), height: min(36, bounds.width * 0.34))
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 12).cgPath
    }
    @objc private func tapped() { onTap?() }
}

final class LaneView: UIControl {
    let lane: TimeLane
    private let name: UILabel
    private let hint: UILabel
    private let empty = UILabel()
    private let dash = CAShapeLayer()
    var contentCard: CardView?
    var onTap: (() -> Void)?
    var accepting = false { didSet { layer.borderWidth = accepting ? 3 : 1.5; layer.borderColor = (accepting ? UIColor.white : lane.tint.withAlphaComponent(0.6)).cgColor } }
    init(_ lane: TimeLane, card: FieldCard?) {
        self.lane = lane
        name = gameLabel(lane.title, size: 19, color: lane.tint, weight: .heavy, alignment: .center)
        hint = gameLabel(lane.hint, size: 9, color: lane.tint.withAlphaComponent(0.9), alignment: .center)
        super.init(frame: .zero)
        backgroundColor = lane.tint.withAlphaComponent(0.09)
        layer.cornerRadius = 14; layer.borderWidth = 1.5; layer.borderColor = lane.tint.withAlphaComponent(0.6).cgColor
        addSubview(name); addSubview(hint)
        dash.strokeColor = lane.tint.withAlphaComponent(0.7).cgColor
        dash.lineWidth = 2; dash.lineDashPattern = [5, 4]; dash.fillColor = UIColor.clear.cgColor
        layer.addSublayer(dash)
        empty.text = "+"; empty.font = Palette.font(32, .medium); empty.textColor = lane.tint; empty.textAlignment = .center
        addSubview(empty)
        if let card = card {
            let view = CardView(card.kind); view.fieldCard = card; view.isUserInteractionEnabled = false
            contentCard = view; addSubview(view); empty.isHidden = true; dash.isHidden = true
        }
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
        isAccessibilityElement = true
        accessibilityLabel = "\(lane.title) slot, \(card?.name ?? "empty"), \(lane.hint)"
        accessibilityTraits = .button
        accessibilityIdentifier = "lane.\(lane.rawValue)"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        name.frame = CGRect(x: 2, y: 8, width: bounds.width - 4, height: 25)
        hint.frame = CGRect(x: 2, y: 34, width: bounds.width - 4, height: 16)
        let rect = CGRect(x: 8, y: 56, width: bounds.width - 16, height: bounds.height - 65)
        contentCard?.frame = rect
        dash.path = UIBezierPath(roundedRect: rect.insetBy(dx: 3, dy: 3), cornerRadius: 10).cgPath
        empty.frame = rect
    }
    @objc private func tapped() { onTap?() }
}

final class HealthBar: UIView {
    private let track = UIView()
    private let bar = UIView()
    private let label = UILabel()
    var fraction: CGFloat = 1
    init(current: Int, maximum: Int) {
        super.init(frame: .zero)
        fraction = CGFloat(current) / CGFloat(max(1, maximum))
        track.backgroundColor = UIColor(hex: 0x0B103E); track.layer.cornerRadius = 9
        bar.backgroundColor = UIColor(hex: 0xFC567F); bar.layer.cornerRadius = 8
        label.text = "\(current) / \(maximum)"; label.textColor = .white
        label.font = Palette.font(13, .heavy); label.textAlignment = .center
        addSubview(track); addSubview(bar); addSubview(label)
        isAccessibilityElement = true; accessibilityLabel = "Enemy HP \(current) of \(maximum)"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews(); track.frame = bounds
        bar.frame = CGRect(x: 2, y: 2, width: max(0, (bounds.width - 4) * fraction), height: max(0, bounds.height - 4))
        label.frame = bounds
    }
}
