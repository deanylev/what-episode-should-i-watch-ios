//
//  APIWrapper.swift
//  WhatEpisodeShouldIWatch
//
//  Created by Dean Levinson on 29/10/2023.
//

import Foundation

let apiUrl = "whatepisodeshouldiwatch.com"

enum FetchError: Error {
    case invalidURL
    case dataFetchError(Error)
    case decodingError
}

struct Show: Decodable, Identifiable {
    let id: String
    let popularity: Float
    let posterUrl: String?
    let title: String
    let yearStart: String
}

struct Episode: Decodable {
    let episode: Int
    let plot: String
    let posterUrl: String?
    let rating: String
    let season: Int
    let showYearEnd: String?
    let title: String
    let totalSeasons: Int
    let year: String
}

struct EpisodeShow: Decodable {
    let episode: Episode
    let show: Show
}

var sampleShows = [
    Show(
        id: "1400",
        popularity: 1003.531,
        posterUrl: "https://image.tmdb.org/t/p/original//aCw8ONfyz3AhngVQa1E2Ss4KSUQ.jpg",
        title: "Seinfeld",
        yearStart: "1989"
    )
]

var sampleEpisodes = [
    Episode(
        episode: 8,
        plot: "George is hot for a potential baldness remedy, and for Elaine after she plays a joke on Jerry.",
        posterUrl: "https://image.tmdb.org/t/p/original//r6cIm9gAoySQictBcevaGj70LBf.jpg",
        rating: "8.3",
        season: 3,
        showYearEnd: "1998",
        title: "The Tape",
        totalSeasons: 9,
        year: "1991"
    )
]

struct APIWrapper {
    static func fetch<T: Decodable>(path: String, params: [String: String]) async throws -> T {
        var url: URL? {
            var components = URLComponents()
            components.scheme = "https"
            components.host = apiUrl
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

    static func fetchEpisode(
        id: String,
        seenEpisodes: [SeenEpisode],
        seasonMin: Int? = nil,
        seasonMax: Int? = nil
    ) async throws -> EpisodeShow {
        var params: [String: String] = [:]
        if seasonMin != nil {
            params["seasonMin"] = String(seasonMin!)
        }
        if seasonMax != nil {
            params["seasonMax"] = String(seasonMax!)
        }
        var flattenedSeenEpisodes: [[Int]] = []
        seenEpisodes.forEach { seenEpisode in
            flattenedSeenEpisodes.append([seenEpisode.season, seenEpisode.episode])
        }

        if let data = try? JSONSerialization.data(withJSONObject: flattenedSeenEpisodes, options: []) {
            params["history"] = String(data: data, encoding: String.Encoding.utf8)
        }
        return try await fetch(path: "episodes/\(id)", params: params)
    }

    static func fetchShows(search: String) async throws -> [Show] {
        if search.isEmpty {
            return []
        }

        return try await fetch(path: "shows", params: ["q": search])
    }
}
