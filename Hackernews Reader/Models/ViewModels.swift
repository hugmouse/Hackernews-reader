import Foundation

enum SearchResultType {
  case story
  case comment
}

struct SearchResult: Identifiable, Hashable {
  let id = UUID()
  let type: SearchResultType
  let storyId: Int
  let commentId: Int?
  let title: String
  let content: String
  let author: String
  let timestamp: Int
  let matchedText: String
  let contextBefore: String
  let contextAfter: String
}

@MainActor
class HackerNewsViewModel: ObservableObject {
  @Published var stories: [Story] = []
  @Published var isLoading = false
  @Published var readStoryIds: Set<Int> = []
  @Published var isLiveUpdatesEnabled = true

  // Method to get updated story instance after Firebase refresh
  func getUpdatedStory(for selectedStory: Story?) -> Story? {
    guard let selectedStory = selectedStory else { return nil }
    return stories.first { $0.id == selectedStory.id }
  }

  // Mark a story as read
  func markStoryAsRead(_ story: Story) {
    readStoryIds.insert(story.id)
  }

  // Check if a story has been read
  func isStoryRead(_ story: Story) -> Bool {
    return readStoryIds.contains(story.id)
  }

  private var _currentCategory: StoryCategory?
  private var currentObserverToken: ObserverToken?

  var currentCategory: StoryCategory? { _currentCategory }

  func loadTopStories() {
    loadStories(for: .top)
  }

  func loadStories(for category: StoryCategory) {
    // Stop any existing observers for the previous category BEFORE updating currentCategory
    if let token = currentObserverToken {
      Task {
        await HackerNewsAPIService.shared.stopObserving(token: token)
      }
      currentObserverToken = nil
    }

    // Now update to new category
    _currentCategory = category
    isLoading = true

    if isLiveUpdatesEnabled {
      // Use live updates and store the observer token
      Task {
        currentObserverToken = await HackerNewsAPIService.shared.observeStories(for: category, limit: 100) {
          [weak self] stories in
          guard let self = self else { return }
          Task { @MainActor in
            // Only update if we're still on the same category (prevent race conditions)
            guard self._currentCategory == category else {
              return
            }

            self.stories = stories
            self.isLoading = false
          }
        }
      }
    } else {
      // Use one-time fetch
      Task { @MainActor in
        do {
          let stories = try await HackerNewsAPIService.shared.fetchStories(
            for: category, limit: 100)
          self.stories = stories
          self.isLoading = false
        } catch {
          self.isLoading = false
        }
      }
    }
  }

  func toggleLiveUpdates() {
    isLiveUpdatesEnabled.toggle()

    if isLiveUpdatesEnabled {
      // Re-enable live updates for current category
      if let category = _currentCategory {
        loadStories(for: category)
      }
    } else {
      // Stop current observer
      if let token = currentObserverToken {
        Task {
          await HackerNewsAPIService.shared.stopObserving(token: token)
        }
        currentObserverToken = nil
      }
    }
  }

  deinit {
    if let token = currentObserverToken {
      Task {
        await HackerNewsAPIService.shared.stopObserving(token: token)
      }
    }
  }

}

@MainActor
class StoryDetailViewModel: ObservableObject {
  @Published var comments: [Comment] = []
  @Published var isLoading = false
  @Published var isLiveUpdatesEnabled = true

  private var currentCommentIds: [Int] = []
  private var currentStoryId: Int?
  private var currentObserverToken: ObserverToken?
  private let viewModelId = UUID()

  deinit {
    if let token = currentObserverToken {
      Task {
        await HackerNewsAPIService.shared.stopObserving(token: token)
      }
    }
  }

  func cleanup() {
    if let token = currentObserverToken {
      Task {
        await HackerNewsAPIService.shared.stopObserving(token: token)
      }
      currentObserverToken = nil
    }

    comments.removeAll()
    currentCommentIds.removeAll()
    currentStoryId = nil
    isLoading = false
  }

  func loadComments(for story: Story) {

    if let token = currentObserverToken {
      Task {
        await HackerNewsAPIService.shared.stopObserving(token: token)
      }
      currentObserverToken = nil
    }

    currentStoryId = story.id
    currentCommentIds = story.kids ?? []
    comments = []
    isLoading = true

    if isLiveUpdatesEnabled && !currentCommentIds.isEmpty {
      // Use live updates for comments and store the observer token
      Task {
        currentObserverToken = await HackerNewsAPIService.shared.observeComments(for: story.id) {
          [weak self] comments in
          guard let self = self else { return }
          Task { @MainActor in
            // Only update if we're still viewing the same story (prevent race conditions)
            guard self.currentStoryId == story.id else {
              return
            }
            self.comments = comments
            self.isLoading = false
          }
        }
      }
    } else {
      // Use one-time fetch for comments
      Task { @MainActor in
        do {
          let comments = try await HackerNewsAPIService.shared.fetchComments(currentCommentIds)
          self.comments = comments
          self.isLoading = false
        } catch {
          self.isLoading = false
        }
      }
    }
  }

  // Backward compatibility method
  func loadComments(for commentIds: [Int]) {
    let dummyStory = Story(
      id: 0, title: "", by: "", time: 0, score: 0, descendants: nil, url: nil, text: nil,
      kids: commentIds, type: "story"
    )
    loadComments(for: dummyStory)
  }
}

// CommentViewModel no longer needed - replies are loaded recursively in Comment struct

@MainActor
class UserViewModel: ObservableObject {
  @Published var user: User?
  @Published var isLoading = false
  @Published var errorMessage: String?

  func loadUser(username: String) {
    isLoading = true
    errorMessage = nil

    Task { @MainActor in
      do {
        let user = try await HackerNewsAPIService.shared.fetchUser(username: username)
        self.user = user
        self.isLoading = false
        self.errorMessage = nil
      } catch {
        self.errorMessage = "Failed to load user profile"
        self.isLoading = false
      }
    }
  }
}
