import Cocoa

/// View representing the DockTile icon
///
/// Dimensions:
/// - Dock tile is 128x128 (but includes a recommended transparent margin of 12)
/// - "Canvas" (visible part) is 104x104
class DockTileView: NSView {
    enum BroadcastState {
        case Off
        case On
        case Broadcasting1
        case Broadcasting2
        case Broadcasting3
    }
    struct Model: Equatable {
        let leftIndicator: Bool?
        let centerIndicator: Bool?
        let rightIndicator: Bool?
        let broadcastState: BroadcastState
    }
    
    private static let backgroundColor: CGColor = .init(
        red: 0.975, green: 0.975, blue: 0.975, alpha: 1.0
    )
    private static let colorForNil: CGColor = .clear
    private static let colorForFalse: CGColor = NSColor.red.cgColor
    private static let colorForTrue: CGColor = NSColor.green.cgColor
    private static let margin = 9.0 // = canvasCornerRadius - (indicatorDiameter / 2)
    private static let broadcastViewWidth = 104 - margin * 2 // 90 = canvasWidth - 2x margin
    private static let broadcastViewHeight = 104 - margin * 2 - 27 - 3 // 56 = canvasHeight - 2x margin - indicatorDiameter - 3
    private static let ringGray: CGColor = .init(gray: 0.75, alpha: 1.0)
    private static let towerOffView: NSView = initTowerView(
        width: broadcastViewWidth, height: broadcastViewHeight, ringColors: []
    )
    private static let towerOnView: NSView = initTowerView(
        width: broadcastViewWidth, height: broadcastViewHeight,
        ringColors: [ringGray, ringGray, ringGray]
    )
    private static let towerBroadcasting1View: NSView = initTowerView(
        width: broadcastViewWidth, height: broadcastViewHeight,
        ringColors: [ringGray, ringGray, .black]
    )
    private static let towerBroadcasting2View: NSView = initTowerView(
        width: broadcastViewWidth, height: broadcastViewHeight,
        ringColors: [ringGray, .black, ringGray]
    )
    private static let towerBroadcasting3View: NSView = initTowerView(
        width: broadcastViewWidth, height: broadcastViewHeight,
        ringColors: [.black, ringGray, ringGray]
    )
    
    private static func colorFor(value: Bool?) -> CGColor {
        switch value {
        case nil: colorForNil
        case .some(false): colorForFalse
        case .some(true): colorForTrue
        }
    }
    
    private static func valueOf(color: CGColor?) -> Bool? {
        switch color {
        case colorForFalse: false
        case colorForTrue: true
        default: nil
        }
    }
    
    private static func viewFor(value: BroadcastState) -> NSView {
        switch value {
        case .Off: towerOffView
        case .On: towerOnView
        case .Broadcasting1: towerBroadcasting1View
        case .Broadcasting2: towerBroadcasting2View
        case .Broadcasting3: towerBroadcasting3View
        }
    }
    
    private static func valueOf(view: NSView?) -> BroadcastState {
        switch view {
        case towerOnView: .On
        case towerBroadcasting1View: .Broadcasting1
        case towerBroadcasting2View: .Broadcasting2
        case towerBroadcasting3View: .Broadcasting3
        default: .Off
        }
    }
    
    private static func initIndicatorView(
        diameter: CGFloat, center: CGPoint
    ) -> NSView {
        let radius = diameter / 2
        let radiusOffset = CGVector(dx: radius, dy: radius)
        let view = NSView(
            frame: .init(
                origin: center - radiusOffset,
                size: .init(width: diameter, height: diameter)
            )
        )
        view.wantsLayer = true
        view.layer?.cornerRadius = radius
        view.layer?.backgroundColor = .clear
        
        return view
    }
    
    private static func initCircleView(
        diameter: CGFloat, center: CGPoint, color: CGColor
    ) -> NSView {
        let radius = diameter / 2
        let radiusOffset = CGVector(dx: radius, dy: radius)
        let view = NSView(
            frame: .init(
                origin: center - radiusOffset,
                size: .init(width: diameter, height: diameter)
            )
        )
        view.wantsLayer = true
        view.layer?.backgroundColor = color
        view.layer?.cornerRadius = radius
        
        return view
    }
    
    private static func initTowerView(
        width: Double, height: Double, ringColors: [CGColor]
    ) -> NSView {
        let view: NSView = NSView(
            frame: .init(
                origin: .init(x: 0, y: 0),
                size: .init(width: width, height: height)
            )
        )
        view.wantsLayer = true
        view.layer?.backgroundColor = backgroundColor
        view.layer?.masksToBounds = true
        let broadcastCenterHeight = 33.0
        let diameters = stride(from: (height - broadcastCenterHeight) * 2, to: 0, by: -15.0)
        for (diameter, color) in zip(diameters, ringColors) {
            let blackCircleView = initCircleView(
                diameter: diameter, center: .init(x: width / 2, y: broadcastCenterHeight), color: color
            )
            view.addSubview(blackCircleView)
            
            let whiteCircleView = initCircleView(
                diameter: diameter - 7.5, center: .init(x: width / 2, y: broadcastCenterHeight), color: backgroundColor
            )
            view.addSubview(whiteCircleView)
        }
        let towerWidth = 5.0
        let towerHeight = broadcastCenterHeight + towerWidth / 2
        let towerBackgroundWidth = towerWidth + 4 // = 5 + 2 + 2
        let towerBackgroundHeight = broadcastCenterHeight + (towerWidth / 2) + 2
        let towerBackgroundView = NSView(
            frame: .init(
                origin: .init(x: (width - towerBackgroundWidth) / 2 , y: 0),
                size: .init(width: towerBackgroundWidth, height: towerBackgroundHeight)
            )
        )
        towerBackgroundView.wantsLayer = true
        towerBackgroundView.layer?.backgroundColor = backgroundColor
        towerBackgroundView.layer?.cornerRadius = towerBackgroundWidth / 2
        view.addSubview(towerBackgroundView)
        
        let towerView = NSView(
            frame: .init(
                origin: .init(x: (width - towerWidth) / 2 , y: 0),
                size: .init(width: towerWidth, height: towerHeight)
            )
        )
        towerView.wantsLayer = true
        towerView.layer?.backgroundColor = .black
        towerView.layer?.cornerRadius = towerWidth / 2
        view.addSubview(towerView)
        
        return view
    }
    
    private let leftIndicatorView: NSView
    private let centerIndicatorView: NSView
    private let rightIndicatorView: NSView
    private let broadcastView: NSView
    private let dockTile: NSDockTile
    
    public init(_ dockTile: NSDockTile) {
        let canvasSide: CGFloat = 104
        let canvasCornerRadius: CGFloat = 22.5
        let indicatorDiameter: CGFloat = 27
        
        leftIndicatorView = Self.initIndicatorView(
            diameter: indicatorDiameter,
            center: .init(x: canvasCornerRadius, y: canvasCornerRadius)
        )
        
        centerIndicatorView = Self.initIndicatorView(
            diameter: indicatorDiameter,
            center: .init(x: canvasSide / 2, y: canvasCornerRadius)
        )
        
        rightIndicatorView = Self.initIndicatorView(
            diameter: indicatorDiameter,
            center: .init(
                x: canvasSide - canvasCornerRadius, y: canvasCornerRadius
            )
        )
        
        broadcastView = NSView(
            frame: .init(
                origin: .init(x: Self.margin, y: 27 + Self.margin + 3),
                size: .init(width: Self.broadcastViewWidth, height: Self.broadcastViewHeight)
            )
        )
        broadcastView.addSubview(Self.towerOffView)
        
        let shadow = NSShadow()
        shadow.shadowColor = .black.withAlphaComponent(0.75)
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.shadowBlurRadius = 2
        
        let canvasOffset: CGFloat = (128 - canvasSide) / 2
        let canvasOrigin = CGPoint(x: canvasOffset, y: canvasOffset)
        let canvas: NSView = NSView(
            frame: .init(
                origin: canvasOrigin,
                size: .init(width: canvasSide, height: canvasSide)
            )
        )
        canvas.wantsLayer = true
        canvas.layer?.backgroundColor = Self.backgroundColor
        canvas.layer?.cornerRadius = canvasCornerRadius
        canvas.shadow = shadow
        canvas.addSubview(leftIndicatorView)
        canvas.addSubview(centerIndicatorView)
        canvas.addSubview(rightIndicatorView)
        canvas.addSubview(broadcastView)
        
        self.dockTile = dockTile
        
        super.init(
            frame: NSRect(origin: .zero, size: NSSize(width: 128, height: 128))
        )
        addSubview(canvas)
        dockTile.contentView = self
        dockTile.display()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var value: Model {
        get {
            Model(
                leftIndicator: Self.valueOf(color: leftIndicatorView.layer?.backgroundColor),
                centerIndicator: Self.valueOf(color: centerIndicatorView.layer?.backgroundColor),
                rightIndicator: Self.valueOf(color: rightIndicatorView.layer?.backgroundColor),
                broadcastState: Self.valueOf(view: broadcastView.subviews.first)
            )
        }
        set(newValue) {
            leftIndicatorView.layer?.backgroundColor = Self.colorFor(value: newValue.leftIndicator)
            centerIndicatorView.layer?.backgroundColor = Self.colorFor(value: newValue.centerIndicator)
            rightIndicatorView.layer?.backgroundColor = Self.colorFor(value: newValue.rightIndicator)
            broadcastView.subviews.removeAll()
            broadcastView.addSubview(Self.viewFor(value: newValue.broadcastState))
            dockTile.display()
        }
    }
}
