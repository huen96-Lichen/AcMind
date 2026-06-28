import SwiftUI

struct CaptureWorkspaceView: View {
    let clipboardPinActions: ClipboardPinActions
    private let previewScenario: AcWorkPreviewScenario?

    init(
        clipboardPinActions: ClipboardPinActions,
        previewScenario: AcWorkPreviewScenario? = nil
    ) {
        self.clipboardPinActions = clipboardPinActions
#if DEBUG
        self.previewScenario = previewScenario ?? DebugAcWorkPreviewScenario.resolve()
#else
        self.previewScenario = previewScenario
#endif
    }

    var body: some View {
        InboxView(
            clipboardPinActions: clipboardPinActions,
            previewScenario: previewScenario
        )
    }
}
