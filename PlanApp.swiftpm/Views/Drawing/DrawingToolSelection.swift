import UIKit

/// The drawing tool currently selected in the custom PencilKit toolbar.
///
/// This is deliberately kept separate from `PKTool`: the toolbar needs to
/// retain the selected color and width while the canvas wrapper translates it
/// into a PencilKit tool.
public enum DrawingToolSelection {
    case pen(color: UIColor)
    case marker(color: UIColor)
    case eraser
}
