import CoreData

final class LocalBufferManager {
    static let shared = LocalBufferManager()
    private let stack = CoreDataStack.shared

    // MARK: - Buffer Samples

    func buffer(_ samples: [HealthSample], batchId: UUID) {
        let context = stack.backgroundContext()
        context.performAndWait {
            for sample in samples {
                let entity = BufferedHealthSample(context: context)
                entity.id = sample.id
                entity.batchId = batchId
                entity.typeIdentifier = sample.typeIdentifier
                entity.value = sample.value
                entity.unit = sample.unit
                entity.startDate = sample.startDate
                entity.endDate = sample.endDate
                entity.sourceBundleId = sample.sourceBundleId
                entity.bufferedAt = Date()
                entity.transmitted = false
            }
            try? context.save()
        }
    }

    // MARK: - Load Untransmitted

    func loadBuffered() -> [HealthSample] {
        let context = stack.viewContext
        let request = BufferedHealthSample.fetchRequest()
        request.predicate = NSPredicate(format: "transmitted == false")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \BufferedHealthSample.bufferedAt, ascending: true)]
        request.fetchLimit = AppConstants.maxBufferedSamplesPerCycle

        guard let results = try? context.fetch(request) else { return [] }
        return results.map { $0.toHealthSample() }
    }

    // MARK: - Mark as Transmitted / Clear Batch

    func clearBatch(_ batchId: UUID) {
        let context = stack.backgroundContext()
        context.performAndWait {
            let request = BufferedHealthSample.fetchRequest()
            request.predicate = NSPredicate(format: "batchId == %@", batchId as CVarArg)
            if let results = try? context.fetch(request) {
                results.forEach { context.delete($0) }
                try? context.save()
            }
        }
    }

    func markBatchTransmitted(_ batchId: UUID) {
        let context = stack.backgroundContext()
        context.performAndWait {
            let request = BufferedHealthSample.fetchRequest()
            request.predicate = NSPredicate(format: "batchId == %@", batchId as CVarArg)
            if let results = try? context.fetch(request) {
                results.forEach { $0.transmitted = true }
                try? context.save()
            }
        }
    }

    // MARK: - Purge Expired

    func purgeExpired() {
        let context = stack.backgroundContext()
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -AppConstants.bufferPurgeDays, to: Date()) else { return }
        context.performAndWait {
            let request = BufferedHealthSample.fetchRequest()
            request.predicate = NSPredicate(format: "bufferedAt < %@", cutoff as CVarArg)
            if let results = try? context.fetch(request) {
                results.forEach { context.delete($0) }
                try? context.save()
            }
        }
    }

    // MARK: - Clear All

    func clearAllBufferedData() {
        let context = stack.backgroundContext()
        context.performAndWait {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "BufferedHealthSample")
            let batchDelete = NSBatchDeleteRequest(fetchRequest: request)
            _ = try? context.execute(batchDelete)
            try? context.save()
        }
    }

    // MARK: - Stats

    func bufferedCount() -> Int {
        let context = stack.viewContext
        let request = BufferedHealthSample.fetchRequest()
        request.predicate = NSPredicate(format: "transmitted == false")
        return (try? context.count(for: request)) ?? 0
    }
}
