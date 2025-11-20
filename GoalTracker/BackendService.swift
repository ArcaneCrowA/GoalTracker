//
//  BackendService.swift
//  GoalTracker
//
//  Created by Adilet Beishekeyev on 20.11.2025.
//

import Foundation

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case serverError(statusCode: Int, message: String?)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL provided was invalid."
        case .noData:
            return "No data was received from the server."
        case .decodingError(let error):
            return "Failed to decode the server response: \(error.localizedDescription)"
        case .serverError(let statusCode, let message):
            return "Server error \(statusCode): \(message ?? "No specific message.")"
        case .unknown(let error):
            return "An unknown error occurred: \(error.localizedDescription)"
        }
    }
}

class BackendService {
    static let shared = BackendService()

    private let baseURL = URL(string: "http://localhost:5001")!

    private init() {}

    func fetchGoals(since lastSyncTimestamp: Date) async throws -> [Goal] {
        guard
            var urlComponents = URLComponents(
                url: baseURL.appendingPathComponent("sync"), resolvingAgainstBaseURL: true)
        else {
            throw NetworkError.invalidURL
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestampString = dateFormatter.string(from: lastSyncTimestamp)

        urlComponents.queryItems = [
            URLQueryItem(name: "last_sync_timestamp", value: timestampString)
        ]

        guard let url = urlComponents.url else {
            throw NetworkError.invalidURL
        }

        print("Fetching goals from: \(url.absoluteString)")

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.noData
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorResponse =
                try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            let errorMessage = errorResponse?["error"] as? String
            throw NetworkError.serverError(
                statusCode: httpResponse.statusCode, message: errorMessage)
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let syncResponse = try decoder.decode(SyncResponse.self, from: data)
            return syncResponse.goals
        } catch {
            print("Decoding error: \(error)")
            throw NetworkError.decodingError(error)
        }
    }
}

struct SyncResponse: Decodable {
    let goals: [GoalResponse]
    let server_timestamp: Date
}

struct GoalResponse: Decodable {
    let id: UUID
    let name: String
    let target_value: Int
    let current_value: Int
    let updated_at: Date
}
