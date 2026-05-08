import Foundation
import CoreGraphics

/// A single event on a timeline measured in minutes from the start of the day.
public struct TimelineEventSlice: Hashable, Sendable {
    public let id: String
    public let startMinute: Int
    public let endMinute: Int

    public init(id: String, startMinute: Int, endMinute: Int) {
        self.id = id
        self.startMinute = max(0, startMinute)
        self.endMinute = max(self.startMinute + 1, endMinute)
    }
}

/// The rendered geometry for a timeline event.
public struct TimelineEventPlacement: Hashable, Sendable {
    public let id: String
    public let startHour: Int
    public let topWithinHour: CGFloat
    public let topOffset: CGFloat
    public let height: CGFloat
    public let lane: Int
    public let laneCount: Int

    public init(
        id: String,
        startHour: Int,
        topWithinHour: CGFloat,
        topOffset: CGFloat,
        height: CGFloat,
        lane: Int,
        laneCount: Int
    ) {
        self.id = id
        self.startHour = startHour
        self.topWithinHour = topWithinHour
        self.topOffset = topOffset
        self.height = height
        self.lane = lane
        self.laneCount = laneCount
    }
}

/// Layout timeline events into non-overlapping visual lanes.
///
/// The algorithm uses visual overlap instead of only time overlap so events that
/// touch in time but still collide because of minimum card height are split into
/// separate lanes.
public func layoutTimelineEvents(
    _ slices: [TimelineEventSlice],
    visibleStartHour: Int,
    hourHeight: CGFloat,
    minimumHeight: CGFloat,
    overlapPadding: CGFloat = 4
) -> [TimelineEventPlacement] {
    struct VisualSlice {
        let id: String
        let startMinute: Int
        let endMinute: Int
        let top: CGFloat
        let height: CGFloat
        let bottom: CGFloat
        let startHour: Int
        let topWithinHour: CGFloat
    }

    let visibleStartMinute = max(0, visibleStartHour) * 60
    let prepared: [VisualSlice] = slices.compactMap { slice in
        let clampedStartMinute = max(slice.startMinute, visibleStartMinute)
        let clampedEndMinute = max(clampedStartMinute + 1, slice.endMinute)

        if clampedEndMinute <= visibleStartMinute {
            return nil
        }

        let durationMinutes = clampedEndMinute - clampedStartMinute
        let relativeStartMinute = clampedStartMinute - visibleStartMinute
        let top = CGFloat(relativeStartMinute) / 60.0 * hourHeight
        let height = max(minimumHeight, CGFloat(durationMinutes) / 60.0 * hourHeight)
        let startHour = clampedStartMinute / 60
        let topWithinHour = CGFloat(clampedStartMinute % 60) / 60.0 * hourHeight

        return VisualSlice(
            id: slice.id,
            startMinute: clampedStartMinute,
            endMinute: clampedEndMinute,
            top: top,
            height: height,
            bottom: top + height,
            startHour: startHour,
            topWithinHour: topWithinHour
        )
    }

    guard prepared.isEmpty == false else {
        return []
    }

    let sorted = prepared.sorted {
        if $0.top == $1.top {
            if $0.bottom == $1.bottom {
                return $0.id < $1.id
            }
            return $0.bottom > $1.bottom
        }
        return $0.top < $1.top
    }

    var placementsByID: [String: TimelineEventPlacement] = [:]
    var currentGroup: [VisualSlice] = []
    var currentGroupBottom: CGFloat = .leastNormalMagnitude

    func flushCurrentGroup() {
        guard currentGroup.isEmpty == false else { return }

        var laneBottoms: [CGFloat] = []
        var laneAssignments: [(slice: VisualSlice, lane: Int)] = []

        for slice in currentGroup {
            var laneIndex: Int?
            for candidateIndex in laneBottoms.indices {
                if laneBottoms[candidateIndex] <= slice.top + overlapPadding {
                    laneIndex = candidateIndex
                    break
                }
            }

            let assignedLane = laneIndex ?? laneBottoms.count
            if assignedLane == laneBottoms.count {
                laneBottoms.append(slice.bottom)
            } else {
                laneBottoms[assignedLane] = slice.bottom
            }
            laneAssignments.append((slice: slice, lane: assignedLane))
        }

        let laneCount = max(1, laneBottoms.count)
        for item in laneAssignments {
            placementsByID[item.slice.id] = TimelineEventPlacement(
                id: item.slice.id,
                startHour: item.slice.startHour,
                topWithinHour: item.slice.topWithinHour,
                topOffset: item.slice.top,
                height: item.slice.height,
                lane: item.lane,
                laneCount: laneCount
            )
        }

        currentGroup.removeAll(keepingCapacity: true)
        currentGroupBottom = .leastNormalMagnitude
    }

    for slice in sorted {
        if currentGroup.isEmpty {
            currentGroup = [slice]
            currentGroupBottom = slice.bottom
            continue
        }

        if slice.top <= currentGroupBottom + overlapPadding {
            currentGroup.append(slice)
            currentGroupBottom = max(currentGroupBottom, slice.bottom)
        } else {
            flushCurrentGroup()
            currentGroup = [slice]
            currentGroupBottom = slice.bottom
        }
    }

    flushCurrentGroup()

    return slices.compactMap { placementsByID[$0.id] }
}
