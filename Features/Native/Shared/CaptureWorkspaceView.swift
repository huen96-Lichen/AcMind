import SwiftUI

struct CaptureWorkspaceView: View {
    let clipboardPinActions: ClipboardPinActions
    private let previewScenario: AcWorkPreviewScenario?

    init(
        clipboardPinActions: ClipboardPinActions,
        previewScenario: AcWorkPreviewScenario? = AcWorkPreviewScenario.fromProcessArguments()
    ) {
        self.clipboardPinActions = clipboardPinActions
        self.previewScenario = previewScenario
    }

    var body: some View {
        InboxView(
            clipboardPinActions: clipboardPinActions,
            previewScenario: previewScenario
        )
    }
}
