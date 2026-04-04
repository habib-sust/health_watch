import CoreData

final class CoreDataStack {
    static let shared = CoreDataStack()

    private let container: NSPersistentContainer

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    func backgroundContext() -> NSManagedObjectContext {
        container.newBackgroundContext()
    }

    private init() {
        // Build the model programmatically since we don't have a .xcdatamodeld file
        let model = Self.createModel()
        container = NSPersistentContainer(name: "HealthWatchBuffer", managedObjectModel: model)
        container.loadPersistentStores { description, error in
            if let error {
                print("[CoreDataStack] Failed to load store: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    // MARK: - Programmatic Model Definition

    private static func createModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // BufferedHealthSample entity
        let entity = NSEntityDescription()
        entity.name = "BufferedHealthSample"
        entity.managedObjectClassName = "BufferedHealthSample"

        // Attributes
        let idAttr = NSAttributeDescription()
        idAttr.name = "id"
        idAttr.attributeType = .UUIDAttributeType
        idAttr.isOptional = false

        let batchIdAttr = NSAttributeDescription()
        batchIdAttr.name = "batchId"
        batchIdAttr.attributeType = .UUIDAttributeType
        batchIdAttr.isOptional = false

        let typeIdentifierAttr = NSAttributeDescription()
        typeIdentifierAttr.name = "typeIdentifier"
        typeIdentifierAttr.attributeType = .stringAttributeType
        typeIdentifierAttr.isOptional = false

        let valueAttr = NSAttributeDescription()
        valueAttr.name = "value"
        valueAttr.attributeType = .doubleAttributeType
        valueAttr.isOptional = false

        let unitAttr = NSAttributeDescription()
        unitAttr.name = "unit"
        unitAttr.attributeType = .stringAttributeType
        unitAttr.isOptional = false

        let startDateAttr = NSAttributeDescription()
        startDateAttr.name = "startDate"
        startDateAttr.attributeType = .dateAttributeType
        startDateAttr.isOptional = false

        let endDateAttr = NSAttributeDescription()
        endDateAttr.name = "endDate"
        endDateAttr.attributeType = .dateAttributeType
        endDateAttr.isOptional = false

        let sourceBundleIdAttr = NSAttributeDescription()
        sourceBundleIdAttr.name = "sourceBundleId"
        sourceBundleIdAttr.attributeType = .stringAttributeType
        sourceBundleIdAttr.isOptional = false

        let bufferedAtAttr = NSAttributeDescription()
        bufferedAtAttr.name = "bufferedAt"
        bufferedAtAttr.attributeType = .dateAttributeType
        bufferedAtAttr.isOptional = false

        let transmittedAttr = NSAttributeDescription()
        transmittedAttr.name = "transmitted"
        transmittedAttr.attributeType = .booleanAttributeType
        transmittedAttr.isOptional = false
        transmittedAttr.defaultValue = false

        entity.properties = [
            idAttr, batchIdAttr, typeIdentifierAttr, valueAttr, unitAttr,
            startDateAttr, endDateAttr, sourceBundleIdAttr, bufferedAtAttr, transmittedAttr
        ]

        // Indexes for frequently queried fields
        let idIndex = NSFetchIndexDescription(name: "byId", elements: [
            NSFetchIndexElementDescription(property: idAttr, collationType: .binary)
        ])
        let batchIndex = NSFetchIndexDescription(name: "byBatchId", elements: [
            NSFetchIndexElementDescription(property: batchIdAttr, collationType: .binary)
        ])
        let bufferedAtIndex = NSFetchIndexDescription(name: "byBufferedAt", elements: [
            NSFetchIndexElementDescription(property: bufferedAtAttr, collationType: .binary)
        ])
        entity.indexes = [idIndex, batchIndex, bufferedAtIndex]

        model.entities = [entity]
        return model
    }
}
