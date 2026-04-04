import CoreData

@objc(BufferedHealthSample)
final class BufferedHealthSample: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var batchId: UUID
    @NSManaged var typeIdentifier: String
    @NSManaged var value: Double
    @NSManaged var unit: String
    @NSManaged var startDate: Date
    @NSManaged var endDate: Date
    @NSManaged var sourceBundleId: String
    @NSManaged var bufferedAt: Date
    @NSManaged var transmitted: Bool
}

extension BufferedHealthSample {
    static func fetchRequest() -> NSFetchRequest<BufferedHealthSample> {
        NSFetchRequest<BufferedHealthSample>(entityName: "BufferedHealthSample")
    }

    /// Convert back to a HealthSample for transmission
    func toHealthSample() -> HealthSample {
        HealthSample(
            id: id,
            typeIdentifier: typeIdentifier,
            value: value,
            unit: unit,
            startDate: startDate,
            endDate: endDate,
            sourceBundleId: sourceBundleId
        )
    }
}
