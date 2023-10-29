//
//  APIWrapper.swift
//  WhatEpisodeShouldIWatch
//
//  Created by Dean Levinson on 29/10/2023.
//

import Foundation

let API_URL = "whatepisodeshouldiwatch.com"

enum FetchError: Error {
    case invalidURL
    case dataFetchError(Error)
    case decodingError
}

struct Show: Decodable, Identifiable {
    let id: String;
    let popularity: Float;
    let posterUrl: String;
    let title: String;
    let yearStart: String;
}

struct APIWrapper {
    static func fetch<T: Decodable>(path: String, params: Dictionary<String, String>) async throws -> T {
        var url: URL? {
            var components = URLComponents()
            components.scheme = "https"
            components.host = API_URL
            components.path = "/\(path)"
            components.queryItems = params.map({ (key: String, value: String) in
                URLQueryItem(name: key, value: value)
            })

            return components.url
        }
        if url == nil {
            throw FetchError.invalidURL
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url!)
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch let urlError as URLError {
            throw FetchError.dataFetchError(urlError)
        } catch {
            throw FetchError.decodingError
        }
    }
    
    static func fetchShows(search: String) async throws -> [Show] {
        if (search.isEmpty) {
            return []
        }
        
        return try await fetch(path: "shows", params: ["q": search])
    }
}
