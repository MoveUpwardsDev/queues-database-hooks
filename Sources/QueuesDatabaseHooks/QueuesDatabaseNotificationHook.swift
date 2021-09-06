import Foundation
import Queues
import FluentKit

/// A `NotificationHook` that can be added to the queues package to track the status of all successful and failed jobs
public struct QueuesDatabaseNotificationHook: JobEventDelegate {
    /// Error-transformation closure.
    private let errorClosure: (Error) -> (String)

    /// Payload-transformation closure.
    private let payloadClosure: (JobEventData) -> (JobEventData)

    /// The database to run the queries on
    public let database: Database

    /// Creates a default `QueuesDatabaseNotificationHook`
    /// - Returns: A `QueuesDatabaseNotificationHook` notification hook handler
    public static func `default`(db: Database) -> QueuesDatabaseNotificationHook {
        return .init(db: db) { error -> (String) in
            return error.localizedDescription
        } payloadClosure: { data -> (JobEventData) in
            return data
        }
    }

    /// Create a new `QueuesNotificationHook`.
    ///
    /// - parameters:
    ///     - closure: Error-transformation closure. Converts `Error` to `String`.
    public init(db: Database, errorClosure: @escaping (Error) -> (String), payloadClosure: @escaping (JobEventData) -> (JobEventData)) {
        self.database = db
        self.errorClosure = errorClosure
        self.payloadClosure = payloadClosure
    }

    /// Called when the job is first dispatched
    /// - Parameters:
    ///   - job: The `JobData` associated with the job
    ///   - eventLoop: The eventLoop
    public func dispatched(job: JobEventData, eventLoop: EventLoop) -> EventLoopFuture<Void> {
        let data = payloadClosure(job)
        let model = QueueDatabaseEntry(
            jobId: data.id,
            jobName: data.jobName,
            queueName: data.queueName,
            payload: Data(data.payload),
            maxRetryCount: data.maxRetryCount,
            delayUntil: data.delayUntil,
            queuedAt: data.queuedAt,
            dequeuedAt: nil,
            completedAt: nil,
            errorString: nil,
            state: .queued
        )
        
        return model.save(on: database).map { _ in
            self.database.logger.info("\(job.id) - Added route to database, db ID \(model.id?.uuidString ?? "")")
        }
    }

    /// Called when the job is dequeued
    /// - Parameters:
    ///   - jobId: The id of the Job
    ///   - eventLoop: The eventLoop
    public func didDequeue(jobId: String, eventLoop: EventLoop) -> EventLoopFuture<Void> {
        self.database.logger.info("\(jobId) - Updating to status of running")
        return QueueDatabaseEntry
            .query(on: database)
            .filter(\.$jobId == jobId)
            .set(\.$state, to: .running)
            .set(\.$dequeuedAt, to: Date())
            .update().map { _ in
                self.database.logger.info("\(jobId) - Done updating to status of running")
            }
    }

    /// Called when the job succeeds
    /// - Parameters:
    ///   - jobId: The id of the Job
    ///   - eventLoop: The eventLoop
    public func success(jobId: String, eventLoop: EventLoop) -> EventLoopFuture<Void> {
        self.database.logger.info("\(jobId) - Updating to status of success")
        
        return QueueDatabaseEntry
            .query(on: database)
            .filter(\.$jobId == jobId)
            .set(\.$state, to: .success)
            .set(\.$completedAt, to: Date())
            .update().map { _ in
                self.database.logger.info("\(jobId) - Done updating to status of success")
            }
    }

    /// Called when the job returns an error
    /// - Parameters:
    ///   - jobId: The id of the Job
    ///   - error: The error that caused the job to fail
    ///   - eventLoop: The eventLoop
    public func error(jobId: String, error: Error, eventLoop: EventLoop) -> EventLoopFuture<Void> {
        self.database.logger.info("\(jobId) - Updating to status of error")
        
        return QueueDatabaseEntry
            .query(on: database)
            .filter(\.$jobId == jobId)
            .set(\.$state, to: .error)
            .set(\.$errorString, to: errorClosure(error))
            .set(\.$completedAt, to: Date())
            .update().map { _ in
                self.database.logger.info("\(jobId) - Done updating to status of error")
            }
    }
}
