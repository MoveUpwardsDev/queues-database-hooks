//
//  JobState.swift
//  
//
//  Created by lgriffie on 06/09/2021.
//

import Foundation

/// The status of the queue job
public enum JobState: String, CaseIterable, Codable {
    public static let schema = "JOB_STATE"

    /// The job has been queued but not yet picked up for processing
    case queued

    /// The job has been moved ot the processing queue and is currently running
    case running

    /// The job has finished and it was successful
    case success

    /// The job has finished and it returned an error
    case error

    /// The job state is unknown
    case unknown

    public init?(rawValue: String) {
        switch rawValue {
        case JobState.queued.rawValue: self = .queued
        case JobState.running.rawValue: self = .running
        case JobState.success.rawValue: self = .success
        case JobState.error.rawValue: self = .error
        default: self = .unknown
        }
    }
}
