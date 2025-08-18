import FirebaseCore
import FirebaseDatabase
import Foundation

@MainActor
final class HackerNewsAPIService: ObservableObject {
    static let shared = HackerNewsAPIService()
    private let database: DatabaseReference
    private var activeObservers: [String: DatabaseHandle] = [:]

    private init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        Database.database().isPersistenceEnabled = true
        self.database =
            Database
            .database(url: "https://hacker-news.firebaseio.com")
            .reference()
    }

    private func fetch<T>(path: String, parser: @escaping (DataSnapshot) -> T?)
        async throws -> T
    {

        return try await withCheckedThrowingContinuation { continuation in
            let ref = database.child(path)
            ref.keepSynced(true)
            ref.observeSingleEvent(of: .value) { snapshot in
                if let parsed = parser(snapshot) {
                    continuation.resume(returning: parsed)
                } else {
                    continuation
                        .resume(throwing: HackerNewsAPIError.parsingFailed)
                }
            } withCancel: { error in
                continuation
                    .resume(throwing: HackerNewsAPIError.networkError(error))
            }
        }
    }

    // MARK: - Batch Fetching
    private func fetchItems<T: Sendable>(
        _ ids: [Int],
        transform: @escaping @Sendable (Int) async -> T?
    ) async -> [T] {

        return await withTaskGroup(of: (Int, T?).self) { group in
            for (index, id) in ids.enumerated() {
                group.addTask { (index, await transform(id)) }
            }

            var resultsDict = [Int: T]()
            var successCount = 0
            var failureCount = 0

            for await (index, item) in group {
                if let item = item {
                    resultsDict[index] = item
                    successCount += 1
                } else {
                    failureCount += 1
                }
            }

            let finalResults = ids.indices.compactMap { index in
                resultsDict[index]
            }

            return finalResults
        }
    }

    func fetchStories(for category: StoryCategory, limit: Int = 10) async throws
        -> [Story]
    {
        do {
            let ids: [Int] = try await fetch(path: "v0/\(category.rawValue)") {
                $0.value as? [Int]
            }
            let limitedIds = Array(ids.prefix(limit))
            let stories = await fetchItems(limitedIds) { id in
                try? await self.fetchStory(id: id)
            }
            return stories
        } catch {
            throw error
        }
    }

    func fetchStory(id: Int) async throws -> Story? {
        do {
            let story = try await fetch(path: "v0/item/\(id)") {
                Story(from: $0)
            }
            return story
        } catch {
            throw error
        }
    }

    func fetchUser(username: String) async throws -> User {
        do {
            let user = try await fetch(path: "v0/user/\(username)") {
                User(from: $0)
            }
            return user
        } catch {
            throw error
        }
    }

    func fetchComments(_ ids: [Int], depth: Int = 0, maxDepth: Int = 10)
        async throws -> [Comment]
    {
        guard depth <= maxDepth else {
            return []
        }
        
        var comments = await fetchItems(ids) { id in
            try? await self.fetchComment(id: id)
        }

        // Load replies for comments that have them
        var commentsWithReplies = 0
        for i in comments.indices where comments[i].kids?.isEmpty == false {
            if let kids = comments[i].kids {
                do {
                    comments[i].replies = try await fetchComments(
                        kids,
                        depth: depth + 1,
                        maxDepth: maxDepth
                    )
                    commentsWithReplies += 1
                } catch {
                    comments[i].replies = nil
                }
            }
        }

        return comments
    }

    private func fetchComment(id: Int) async throws -> Comment? {
        do {
            let comment = try await fetch(path: "v0/item/\(id)") {
                Comment(from: $0)
            }
            return comment
        } catch {
            throw error
        }
    }

    // MARK: - Normal observers (not single)
    func observeStories(for category: StoryCategory, limit: Int = 10)
        -> AsyncStream<[Story]>
    {
        let path = "v0/\(category.rawValue)"

        return AsyncStream { continuation in
            stopObserving(path: path)
            let ref = database.child(path)
            ref.keepSynced(true)
            let handle = ref.observe(.value) { [self] snapshot in
                Task {
                    if let ids = snapshot.value as? [Int] {
                        let limitedIds = Array(ids.prefix(limit))
                        let stories = await self.fetchItems(limitedIds) { id in
                            try? await self.fetchStory(id: id)
                        }
                        continuation.yield(stories)
                    } else {
                        continuation.yield([])
                    }
                }
            }

            activeObservers[path] = handle
            continuation.onTermination = { [self] reason in
                Task { @MainActor in
                    self.stopObserving(path: path)
                }
            }

        }
    }

    func observeComments(for storyId: Int) -> AsyncStream<[Comment]> {
        let path = "v0/item/\(storyId)"

        return AsyncStream { continuation in
            stopObserving(path: path)
            let ref = database.child(path)
            ref.keepSynced(true)

            let handle = ref.observe(.value) { [self] snapshot in
                Task {
                    if let story = Story(from: snapshot) {
                        if let commentIds = story.kids {
                            do {
                                let comments = try await self.fetchComments(
                                    commentIds
                                )
                                continuation.yield(comments)
                            } catch {
                                continuation.yield([])
                            }
                        } else {
                            continuation.yield([])
                        }
                    } else {
                        continuation.yield([])
                    }
                }
            }

            activeObservers[path] = handle
            continuation.onTermination = { [self] reason in

                Task { @MainActor in
                    self.stopObserving(path: path)
                }
            }

        }
    }

    func stopObserving(path: String) {
        if let handle = activeObservers[path] {
            database.child(path).removeObserver(withHandle: handle)
            activeObservers.removeValue(forKey: path)
        }
    }
}
