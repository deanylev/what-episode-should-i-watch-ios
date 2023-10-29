//
//  ContentView.swift
//  WhatEpisodeShouldIWatch
//
//  Created by Dean Levinson on 29/10/2023.
//

import SwiftUI

import CachedAsyncImage

struct SearchView: View {
    @State private var debounceTimer: Timer?
    @State private var search = ""
    @FocusState private var searchFocused
    @State private var searchInFlight = false
    @State private var shows: [Show]

    init(shows: [Show] = []) {
        self.shows = shows
        UILabel.appearance(whenContainedInInstancesOf: [UINavigationBar.self]).adjustsFontSizeToFitWidth = true
    }
        
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 17 / 255, green: 24 / 255, blue: 39 / 255).ignoresSafeArea()
                VStack {
                    Form {
                        TextField("Search for a TV show...", text: $search)
                            .focused($searchFocused)
                            .onAppear {
                                searchFocused = true
                            }
                            .onChange(of: search) {
                                debounceTimer?.invalidate()
                                debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                                    Task {
                                        do {
                                            searchInFlight = true
                                            shows = try await APIWrapper.fetchShows(search: search)
                                        } catch {
                                            print(error)
                                        }
                                        searchInFlight = false
                                    }
                                }
                            }
                    }
                    .scrollContentBackground(.hidden)
                    .navigationTitle("What Episode Should I Watch?")
                    .frame(height: 50)
                    
                    if searchInFlight {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        List {
                            ForEach(shows) { show in
                                HStack {
                                    // TODO handle missing URL
                                    CachedAsyncImage(url: URL(string: show.posterUrl)) { phase in
                                        switch phase {
                                        case .empty:
                                            ProgressView()
                                                .progressViewStyle(.circular)
                                                .frame(width: 70, height: 105)
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 70, height: 105)
                                                .cornerRadius(5)
                                        case .failure:
                                            Image(systemName: "photo")
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 70, height: 105)
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                    Text("\(show.title) (\(show.yearStart))")
                                        .padding(.horizontal)
                                }
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                    
                    Spacer()
                }
            }
        }
    }
}

#Preview {
    let show = Show(
        id: "1400",
        popularity: 1003.531,
        posterUrl: "https://image.tmdb.org/t/p/original//aCw8ONfyz3AhngVQa1E2Ss4KSUQ.jpg",
        title: "Seinfeld",
        yearStart: "1989"
    )
    
    return SearchView(shows: [show])
}
