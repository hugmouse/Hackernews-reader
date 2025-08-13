import FirebaseDatabase
import Foundation

enum HackerNewsAPIError: Error, Sendable {
  case parsingFailed
  case invalidData
  case networkError(Error)
  case observerFailed(Error)
  
  var localizedDescription: String {
    switch self {
    case .parsingFailed:
      return "Failed to parse API response"
    case .invalidData:
      return "Invalid data received from API"
    case .networkError(let error):
      return "Network error: \(error.localizedDescription)"
    case .observerFailed(let error):
      return "Observer failed: \(error.localizedDescription)"
    }
  }
}

enum StoryCategory: String, CaseIterable {
  case top = "topstories"
  case new = "newstories"
  case best = "beststories"
  case ask = "askstories"
  case show = "showstories"
  case job = "jobstories"

  var displayName: String {
    switch self {
    case .top: return "Top"
    case .new: return "New"
    case .best: return "Best"
    case .ask: return "Ask"
    case .show: return "Show"
    case .job: return "Jobs"
    }
  }
}

struct Story: Codable, Hashable, Sendable {
  let id: Int
  let title: String
  let by: String
  let time: Int
  let score: Int
  let descendants: Int?  // TODO: does not exists on job stories, check if exists on others
  let url: String?
  let text: String?
  let kids: [Int]?
  let type: String

  // Firebase initializer
  init?(from snapshot: DataSnapshot) {
    guard let data = snapshot.value as? [String: Any],
      let id = data["id"] as? Int,
      let title = data["title"] as? String,
      let by = data["by"] as? String,
      let time = data["time"] as? Int,
      let score = data["score"] as? Int,
      let type = data["type"] as? String
    else {
      return nil
    }

    self.id = id
    self.title = title
    self.by = by
    self.time = time
    self.score = score
    self.type = type
    self.descendants = data["descendants"] as? Int
    self.url = data["url"] as? String
    self.text = data["text"] as? String
    self.kids = data["kids"] as? [Int]
  }

  // For previews
  init(
    id: Int, title: String, by: String, time: Int, score: Int, descendants: Int?, url: String?,
    text: String?, kids: [Int]?, type: String
  ) {
    self.id = id
    self.title = title
    self.by = by
    self.time = time
    self.score = score
    self.descendants = descendants
    self.url = url
    self.text = text
    self.kids = kids
    self.type = type
  }
}

struct Comment: Codable, Equatable, Sendable {
  let id: Int
  let by: String?  // TODO: check if only "dead" comments don't have "by" field
  let time: Int
  let text: String?
  let kids: [Int]?
  let parent: Int?
  var replies: [Comment]?  // Nested replies loaded recursively

  // Direct Firebase initializer
  init?(from snapshot: DataSnapshot) {
    guard let data = snapshot.value as? [String: Any],
      let id = data["id"] as? Int,
      let time = data["time"] as? Int
    else {
      return nil
    }

    self.id = id
    self.time = time
    self.by = data["by"] as? String
    self.text = data["text"] as? String
    self.kids = data["kids"] as? [Int]
    self.parent = data["parent"] as? Int
    self.replies = nil  // Will be populated by recursive loading
  }

  // For previews
  init(
    id: Int, by: String?, time: Int, text: String?, kids: [Int]?, parent: Int?,
    replies: [Comment]? = nil
  ) {
    self.id = id
    self.by = by
    self.time = time
    self.text = text
    self.kids = kids
    self.parent = parent
    self.replies = replies
  }
}

struct User: Codable, Hashable, Sendable {
  let id: String
  let created: Int
  let karma: Int
  let about: String?
  let submitted: [Int]?

  // Direct Firebase initializer
  init?(from snapshot: DataSnapshot) {
    guard let data = snapshot.value as? [String: Any],
      let id = data["id"] as? String,
      let created = data["created"] as? Int,
      let karma = data["karma"] as? Int
    else {
      return nil
    }

    self.id = id
    self.created = created
    self.karma = karma
    self.about = data["about"] as? String
    self.submitted = data["submitted"] as? [Int]
  }

  // For previews
  init(id: String, created: Int, karma: Int, about: String?, submitted: [Int]?) {
    self.id = id
    self.created = created
    self.karma = karma
    self.about = about
    self.submitted = submitted
  }
}
