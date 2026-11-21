import Foundation

/// Versioned presentation capture. Explicit `.none` entries distinguish a disabled
/// checklist from a leg that has not started. Revision 1 uses the immutable v1 catalog.
nonisolated struct RecordingCockpitContext: Equatable, Sendable {
    var version = 1
    let flightID: UUID
    var checklists: [UUID: LegStartChecklistCapture]
    var areDriftLinesVisible: Bool
    // Runtime ordering identity, deliberately excluded from the durable schema and
    // value equality. A recovered engine starts a new presentation-writing session.
    var navigationGeneration: UUID? = nil

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.version == rhs.version && lhs.flightID == rhs.flightID
            && lhs.checklists == rhs.checklists
            && lhs.areDriftLinesVisible == rhs.areDriftLinesVisible
    }

    func validate(flightID: UUID, legIDs: [UUID]) throws {
        guard version == 1, self.flightID == flightID,
              checklists.allSatisfy({ key, value in
                  key == value.legID && legIDs.contains(key) && value.definitionRevision == 1
                      && (value.selection != .none || value.reviewState == .pending)
              }) else { throw FlightRecoveryError.invalidJournal }
    }

    func starting(legID: UUID, selection: StartChecklistSelection) -> Self {
        var result = self
        if result.checklists[legID] == nil {
            result.checklists[legID] = .init(legID: legID, selection: selection,
                                          reviewState: .pending, presentationState: .expanded,
                                          phaseState: .available)
        }
        return result
    }
}

extension RecordingCockpitContext: Codable {
    private enum CodingKeys: String, CodingKey {
        case version, flightID, checklists, areDriftLinesVisible
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(Int.self, forKey: .version)
        flightID = try values.decode(UUID.self, forKey: .flightID)
        areDriftLinesVisible = try values.decode(Bool.self, forKey: .areDriftLinesVisible)
        let encoded = try values.decode([String: LegStartChecklistCapture].self, forKey: .checklists)
        checklists = [:]
        for (key, capture) in encoded {
            guard let id = UUID(uuidString: key), checklists[id] == nil else {
                throw FlightRecoveryError.invalidJournal
            }
            checklists[id] = capture
        }
    }

    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(version, forKey: .version)
        try values.encode(flightID, forKey: .flightID)
        try values.encode(areDriftLinesVisible, forKey: .areDriftLinesVisible)
        // UUID-keyed dictionaries otherwise encode as order-dependent arrays.
        // String keys allow the journal encoder's sortedKeys to stabilize checksums.
        let encoded = Dictionary(uniqueKeysWithValues: checklists.map { ($0.key.uuidString.lowercased(), $0.value) })
        try values.encode(encoded, forKey: .checklists)
    }
}
