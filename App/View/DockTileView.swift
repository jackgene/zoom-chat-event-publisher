import Cocoa

/// View representing the DockTile icon
///
/// Dimensions:
/// - Dock tile is 128x128 (but includes a recommended transparent margin of 12)
class DockTileView: NSImageView {
    private let dockTile: NSDockTile
    
    public init(_ dockTile: NSDockTile) {
        self.dockTile = dockTile
        
        super.init(
            frame: NSRect(origin: .zero, size: NSSize(width: 128, height: 128))
        )
        dockTile.contentView = self
        dockTile.display()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var image: NSImage? {
        didSet {
            dockTile.display()
        }
    }
}
