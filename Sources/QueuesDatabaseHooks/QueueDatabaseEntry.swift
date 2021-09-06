import Foundation
import FluentKit

/// Stores information about a `Queue` job
/// A record gets added when the job is dispatched
/// and then updated with its status when it succeeds or fails
public final class QueueDatabaseEntry: Model {
    public static let schema = "_queue_job_completions"

    @ID(key: .id)
    public var id: UUID?

    /// The `jobId` that came from the queues package
    @Field(key: "jobId")
    public var jobId: String

    /// The name of the job
    @Field(key: "jobName")
    public var jobName: String

    /// The queue the job was run on
    @Field(key: "queueName")
    public var queueName: String

    /// The data associated with the job
    @Field(key: "payload")
    public var payload: Data

    /// The retry count for the job
    @Field(key: "maxRetryCount")
    public var maxRetryCount: Int

    /// The `delayUntil` date from the queues package
    @OptionalField(key: "delayUntil")
    public var delayUntil: Date?

    /// The date the job was queued at
    @Field(key: "queuedAt")
    public var queuedAt: Date

    /// The date the job was dequeued at
    @OptionalField(key: "dequeuedAt")
    public var dequeuedAt: Date?

    /// The date the job was completed
    @OptionalField(key: "completedAt")
    public var completedAt: Date?

    /// The error string for the job
    @OptionalField(key: "errorString")
    public var errorString: String?

    /// The state of the job
    @Enum(key: "state")
    public var state: JobState

    @Timestamp(key: "createdAt", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    public var updatedAt: Date?

    public init() { }

    public init(
        jobId: String,
        jobName: String,
        queueName: String,
        payload: Data,
        maxRetryCount: Int,
        delayUntil: Date?,
        queuedAt: Date,
        dequeuedAt: Date?,
        completedAt: Date?,
        errorString: String?,
        state: JobState
    ) {
        self.jobId = jobId
        self.jobName = jobName
        self.queueName = queueName
        self.payload = payload
        self.maxRetryCount = maxRetryCount
        self.delayUntil = delayUntil
        self.queuedAt = queuedAt
        self.errorString = errorString
        self.state = state
        self.completedAt = completedAt
        self.createdAt = nil
        self.updatedAt = nil
    }
}

public struct QueueDatabaseEntryMigration: Migration {
    public init() { }

    public func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.enum(JobState.schema)
            .case("queued")
            .case("running")
            .case("success")
            .case("error")
            .create()
            .transform(to: ())
            .flatMap {
                database.schema(QueueDatabaseEntry.schema)
                    .field(.id, .uuid, .identifier(auto: false))
                    .field("jobId", .string, .required)
                    .field("jobName", .string, .required)
                    .field("queueName", .string, .required)
                    .field("payload", .data, .required)
                    .field("maxRetryCount", .int, .required)
                    .field("delayUntil", .datetime)
                    .field("queuedAt", .datetime, .required)
                    .field("dequeuedAt", .datetime)
                    .field("completedAt", .datetime)
                    .field("errorString", .string)
                    .field("createdAt", .datetime)
                    .field("updatedAt", .datetime)
                    .create()
            }
            .flatMap {
                database.enum(JobState.schema).read()
                    .flatMap {
                        database.schema(QueueDatabaseEntry.schema)
                            .field("state", $0, .required)
                            .update()
                    }
            }
    }

    public func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(QueueDatabaseEntry.schema).delete().flatMap { database.enum(JobState.schema).delete() }
    }
}
