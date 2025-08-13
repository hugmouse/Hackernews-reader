import Foundation

@MainActor
class SearchViewModel: ObservableObject {
  @Published var searchResults: [SearchResult] = []
  @Published var filteredStories: [Story] = []
  @Published var isSearching = false
  @Published var searchQuery: String = ""
  @Published var highlightedCommentId: Int?

  private let searchService = SearchService()
  private var searchTask: Task<Void, Never>?
  private var highlightTask: Task<Void, Never>?
  private let debounceDelay: TimeInterval = 0.3
  private var allLoadedComments: [(Story, [Comment])] = []

  deinit {
    searchTask?.cancel()
    highlightTask?.cancel()
  }

  func updateSearchQuery(_ query: String, stories: [Story]) {
    searchTask?.cancel()
    searchQuery = query

    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      isSearching = false
      filteredStories = stories
      searchResults = []
      return
    }

    isSearching = true

    searchTask = Task {
      try? await Task.sleep(nanoseconds: UInt64(debounceDelay * 1_000_000_000))

      if !Task.isCancelled {
        await performSearch(query: query, stories: stories)
      }
    }
  }

  func registerCommentsForSearch(story: Story, comments: [Comment]) {
    if let index = allLoadedComments.firstIndex(where: { $0.0.id == story.id }) {
      allLoadedComments[index] = (story, comments)
    } else {
      allLoadedComments.append((story, comments))
    }
  }

  func selectCommentFromSearch(_ commentId: Int) {
    // Cancel any existing highlight task
    highlightTask?.cancel()

    highlightedCommentId = commentId

    // Clear highlight after 3 seconds
    highlightTask = Task {
      try? await Task.sleep(nanoseconds: 3_000_000_000)
      if !Task.isCancelled {
        highlightedCommentId = nil
      }
    }
  }

  private func performSearch(query: String, stories: [Story]) async {
    let results = searchService.performSearch(
      query: query,
      stories: stories,
      commentsData: allLoadedComments
    )

    let filtered = searchService.filterStories(stories, query: query)

    searchResults = results
    filteredStories = filtered
  }
}
