import Foundation
import Models
import Services

public struct ImportRow: Identifiable, Sendable {
    public let id: String
    public var descriptor: CalendarEventDescriptor
    public var persoonId: UUID?
    public var include: Bool
    public var skipReason: EventMappingService.SkipReason?

    public init(
        descriptor: CalendarEventDescriptor,
        persoonId: UUID?,
        include: Bool,
        skipReason: EventMappingService.SkipReason?
    ) {
        self.id = descriptor.id
        self.descriptor = descriptor
        self.persoonId = persoonId
        self.include = include
        self.skipReason = skipReason
    }
}
