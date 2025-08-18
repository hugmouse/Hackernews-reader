import Foundation

enum SearchResultType {
  case story
  case comment
}

struct SearchResult: Identifiable, Hashable {
  var id: String {
    if let commentId {
        return "\(storyId)-\(commentId)"
   }
    return String(storyId)
  }
  let type: SearchResultType
  let storyId: Int
  let commentId: Int?
  let title: String
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


  func markStoryAsRead(_ story: Story) {
    readStoryIds.insert(story.id)
  }

  func isStoryRead(_ story: Story) -> Bool {
    return readStoryIds.contains(story.id)
  }

  private var _currentCategory: StoryCategory?
  private var observerTask: Task<Void, Never>?


  func loadTopStories() {
    loadStories(for: .top)
  }

  func loadStories(for category: StoryCategory) {
    observerTask?.cancel()
    observerTask = nil
    
    _currentCategory = category
    isLoading = true

    if isLiveUpdatesEnabled {
      observerTask = Task {
        for await stories in HackerNewsAPIService.shared.observeStories(for: category, limit: 100) {
          guard _currentCategory == category, !Task.isCancelled else { return }
          self.stories = stories
          self.isLoading = false
        }
      }
    } else {
      Task {
        do {
          let stories = try await HackerNewsAPIService.shared.fetchStories(for: category, limit: 100)
          guard _currentCategory == category else { return }
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
    
    if let category = _currentCategory {
      loadStories(for: category)
    }
  }

  deinit {
    observerTask?.cancel()
  }
}

@MainActor
class StoryDetailViewModel: ObservableObject {
  @Published var comments: [Comment] = []
  @Published var isLoading = false
  @Published var isLiveUpdatesEnabled = true

  private var currentStoryId: Int?
  private var observerTask: Task<Void, Never>?

  func cleanup() {
    observerTask?.cancel()
    observerTask = nil
    comments.removeAll()
    currentStoryId = nil
    isLoading = false
  }

  func loadComments(for story: Story) {
    observerTask?.cancel()
    observerTask = nil
    
    currentStoryId = story.id
    comments = []
    isLoading = true

    if isLiveUpdatesEnabled && story.kids?.isEmpty == false {
      observerTask = Task {
        for await comments in HackerNewsAPIService.shared.observeComments(for: story.id) {
          guard currentStoryId == story.id, !Task.isCancelled else { return }
          self.comments = comments
          self.isLoading = false
        }
      }
    } else {
      Task {
        do {
          let commentIds = story.kids ?? []
          let comments = try await HackerNewsAPIService.shared.fetchComments(commentIds)
          guard currentStoryId == story.id else { return }
          self.comments = comments
          self.isLoading = false
        } catch {
          self.isLoading = false
        }
      }
    }
  }

  deinit {
    observerTask?.cancel()
  }
}

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
