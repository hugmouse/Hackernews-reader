import FirebaseCore
import FirebaseDatabase
import Foundation

// Token for cancelling Firebase observers
struct ObserverToken {
  let id: UUID
  let path: String
  let handle: DatabaseHandle
  let category: String?
  let createdAt: Date

  init(path: String, handle: DatabaseHandle, category: String? = nil) {
    self.id = UUID()
    self.path = path
    self.handle = handle
    self.category = category
    self.createdAt = Date()
  }
}

final actor HackerNewsAPIService {
  static let shared = HackerNewsAPIService()
  private let database: DatabaseReference
  private var activeObservers: [String: ObserverToken] = [:]

  private init() {
    if FirebaseApp.app() == nil { FirebaseApp.configure() }
    Database.database().isPersistenceEnabled = true
    self.database = Database.database(url: "https://hacker-news.firebaseio.com").reference()
  }

  private func fetch<T>(path: String, parser: @escaping (DataSnapshot) -> T?) async throws -> T {
    try await withCheckedThrowingContinuation { continuation in
      let ref = database.child(path)
      // TODO: Figure out if keepSynced can hurt performance
      ref.keepSynced(true)
      // TODO: Also figure out the idea of replacing single event with normal observer
      ref.observeSingleEvent(of: .value) { snapshot in
        if let parsed = parser(snapshot) {
          continuation.resume(returning: parsed)
        } else {
          continuation.resume(throwing: HackerNewsAPIError.parsingFailed)
        }
      } withCancel: { error in
        continuation.resume(throwing: HackerNewsAPIError.networkError(error))
      }
    }
  }

  private func fetchItems<T: Sendable>(
    _ ids: [Int],
    transform: @escaping @Sendable (Int) async -> T?
  ) async -> [T] {
    await withTaskGroup(of: T?.self) { group in
      for id in ids {
        group.addTask { await transform(id) }
      }
      
      return await group.reduce(into: [T]()) { results, item in
        if let item = item {
          results.append(item)
        }
      }
    }
  }

  func fetchStories(for category: StoryCategory, limit: Int = 100) async throws -> [Story] {
    let ids: [Int] = try await fetch(path: "v0/\(category.rawValue)") { $0.value as? [Int] }
    let stories = await fetchItems(Array(ids.prefix(limit))) { @Sendable id in
      try? await HackerNewsAPIService.shared.fetchStory(id: id)
    }
    return stories
  }

  func fetchStory(id: Int) async throws -> Story? {
    do {
      let story = try await fetch(path: "v0/item/\(id)") { Story(from: $0) }
      return story
    } catch {
      return nil
    }
  }

  func fetchUser(username: String) async throws -> User {
    try await fetch(path: "v0/user/\(username)") { User(from: $0) }
  }

  func fetchComments(_ ids: [Int], depth: Int = 0, maxDepth: Int = 10) async throws -> [Comment] {
    guard depth <= maxDepth else { return [] }
    var comments = await fetchItems(ids) { @Sendable id in
      try? await HackerNewsAPIService.shared.fetchComment(id: id)
    }

    await withTaskGroup(of: (Int, [Comment]).self) { group in
      for (index, comment) in comments.enumerated() where comment.kids?.isEmpty == false {
        let kids = comment.kids!
        let currentDepth = depth
        group.addTask { @Sendable in
          let replies = try? await HackerNewsAPIService.shared.fetchComments(
            kids, depth: currentDepth + 1, maxDepth: maxDepth)
          return (index, replies ?? [])
        }
      }

      for await (index, replies) in group {
        comments[index].replies = replies
      }
    }

    return comments
  }

  private func fetchComment(id: Int) async throws -> Comment? {
    try await fetch(path: "v0/item/\(id)") { Comment(from: $0) }
  }
  
  private func resolveObserverPath(_ path: String) -> String {
    return path.replacingOccurrences(of: "_comments", with: "")
  }
  
  private func callOnMainActor<T: Sendable>(_ completion: @escaping @Sendable (T) -> Void, with value: T) {
    Task { @MainActor in
      completion(value)
    }
  }

  // Observe story list changes in real-time
  @discardableResult
  func observeStories(
    for category: StoryCategory, limit: Int = 100, completion: @escaping @Sendable ([Story]) -> Void
  ) -> ObserverToken {
    let path = "v0/\(category.rawValue)"

    // Remove existing observer if any
    stopObserving(path: path)

    let ref = database.child(path)
    ref.keepSynced(true)

    let handle = ref.observe(.value) { snapshot in
      if let ids = snapshot.value as? [Int] {
        let idsToFetch = Array(ids.prefix(limit))

        Task {
          let stories = await HackerNewsAPIService.shared.fetchItems(idsToFetch) { @Sendable id in
            try? await HackerNewsAPIService.shared.fetchStory(id: id)
          }
          await HackerNewsAPIService.shared.callOnMainActor(completion, with: stories)
        }
      }
    }

    let token = ObserverToken(path: path, handle: handle, category: category.displayName)
    activeObservers[path] = token

    return token
  }

  // Observe individual story changes
  @discardableResult
  func observeStory(id: Int, completion: @escaping @Sendable (Story?) -> Void) -> ObserverToken {
    let path = "v0/item/\(id)"

    // Remove existing observer if any
    stopObserving(path: path)

    let ref = database.child(path)
    ref.keepSynced(true)

    let handle = ref.observe(.value) { snapshot in
      let story = Story(from: snapshot)
      Task {
        await HackerNewsAPIService.shared.callOnMainActor(completion, with: story)
      }
    }

    let token = ObserverToken(path: path, handle: handle, category: "Story-\(id)")
    activeObservers[path] = token

    return token
  }

  // Observe comments for a story in real-time
  @discardableResult
  func observeComments(for storyId: Int, completion: @escaping @Sendable ([Comment]) -> Void)
    -> ObserverToken
  {
    let path = "v0/item/\(storyId)_comments"

    // Remove existing observer if any
    stopObserving(path: path)

    let storyPath = "v0/item/\(storyId)"
    let ref = database.child(storyPath)
    ref.keepSynced(true)

    let handle = ref.observe(.value) { snapshot in
      if let story = Story(from: snapshot), let commentIds = story.kids {
        Task {
          do {
            let comments = try await HackerNewsAPIService.shared.fetchComments(commentIds)
            await HackerNewsAPIService.shared.callOnMainActor(completion, with: comments)
          } catch {
            await HackerNewsAPIService.shared.callOnMainActor(completion, with: [])
          }
        }
      } else {
        Task {
          await HackerNewsAPIService.shared.callOnMainActor(completion, with: [])
        }
      }
    }

    let token = ObserverToken(path: path, handle: handle, category: "Comments-\(storyId)")
    activeObservers[path] = token

    return token
  }

  // Stop observing a specific path
  func stopObserving(path: String) {
    if let token = activeObservers[path] {
      let resolvedPath = resolveObserverPath(token.path)
      let ref = database.child(resolvedPath)
      ref.removeObserver(withHandle: token.handle)
      activeObservers.removeValue(forKey: path)
    }
  }

  // Stop observing using a token
  func stopObserving(token: ObserverToken) {
    if let existingToken = activeObservers[token.path], existingToken.id == token.id {
      let resolvedPath = resolveObserverPath(token.path)
      let ref = database.child(resolvedPath)
      ref.removeObserver(withHandle: token.handle)
      activeObservers.removeValue(forKey: token.path)
    }
  }

  // Stop it all
  func stopAllObservers() {
    for (_, token) in activeObservers {
      let resolvedPath = resolveObserverPath(token.path)
      let ref = database.child(resolvedPath)
      ref.removeObserver(withHandle: token.handle)
    }
    activeObservers.removeAll()
  }

}
