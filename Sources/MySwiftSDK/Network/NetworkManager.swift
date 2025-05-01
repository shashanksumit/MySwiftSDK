//
//  NetworkManager.swift
//  MySwiftSDK
//
//  Created by Shashank Singh on 01/05/25.
//

import Foundation

public enum HTTPMethod: String {
    case GET, POST, PUT, DELETE, PATCH
}

public enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case statusCode(Int)
    case decodingError(Error)
    case other(Error)
}

/// Final class with no mutable shared state (safe for concurrency)
public final class NetworkManager {
    @MainActor public static let shared = NetworkManager()
    private let session: URLSession

    private init() {
        self.session = URLSession(configuration: .default)
    }

    public func request<T: Decodable, B: Encodable>(
        url: String,
        method: HTTPMethod = .GET,
        headers: [String: String]? = nil,
        body: B? = nil,
        responseType: T.Type
    ) async throws -> T {
        guard let url = URL(string: url) else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        if let headers = headers {
            headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        }

        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.statusCode(httpResponse.statusCode)
            }

            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw NetworkError.decodingError(error)
            }
        } catch {
            throw NetworkError.other(error)
        }
    }
}
