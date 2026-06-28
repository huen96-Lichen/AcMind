import SwiftUI

#if DEBUG
extension WorkbenchV2CurrentFocusActions {
    static var previewOnly: WorkbenchV2CurrentFocusActions {
        WorkbenchV2CurrentFocusActions(
            continueWork: {},
            viewDetails: {},
            selectBackground: {}
        )
    }
}

extension WorkbenchV2QuickActionHandlers {
    static var previewOnly: WorkbenchV2QuickActionHandlers {
        WorkbenchV2QuickActionHandlers(
            screenshot: {},
            quickRecord: {},
            createTask: {},
            openInbox: {},
            startAgent: {},
            importFiles: {},
            addSchedule: {}
        )
    }
}
#endif
