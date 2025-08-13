import Foundation

struct ProcessedComment {
  let original: Comment
  let processedText: String
  let processedReplies: [ProcessedComment]?
}

struct ProcessedStory {
  let original: Story
  let processedText: String?
}

// TODO: Lags badly when we have, like, 1000 comments. Need to refactor.
class SearchService {

  func performSearch(
    query: String,
    stories: [Story],
    commentsData: [(Story, [Comment])]
  ) -> [SearchResult] {
    let lowercaseQuery = query.lowercased()
    var results: [SearchResult] = []

    // Preprocess stories
    let processedStories = preprocessStories(stories)
    for processedStory in processedStories {
      if let storyResult = searchInProcessedStory(processedStory, query: lowercaseQuery) {
        results.append(storyResult)
      }
    }

    // Preprocess comments
    let processedCommentsData = preprocessCommentsData(commentsData)
    for (story, processedComments) in processedCommentsData {
      let commentResults = searchInProcessedComments(story: story, comments: processedComments, query: lowercaseQuery)
      results.append(contentsOf: commentResults)
    }

    return sortSearchResults(results, query: lowercaseQuery)
  }

  func filterStories(_ stories: [Story], query: String) -> [Story] {
    let lowercaseQuery = query.lowercased()
    return stories.filter { story in
      story.title.lowercased().contains(lowercaseQuery)
        || (story.text?.lowercased().contains(lowercaseQuery) == true)
    }
  }

  private func preprocessStories(_ stories: [Story]) -> [ProcessedStory] {
    return stories.map { story in
      let processedText = story.text != nil ? HTMLParser.stripHTML(story.text!) : nil
      return ProcessedStory(original: story, processedText: processedText)
    }
  }

  private func preprocessCommentsData(_ commentsData: [(Story, [Comment])]) -> [(Story, [ProcessedComment])] {
    return commentsData.map { (story, comments) in
      let processedComments = preprocessComments(comments)
      return (story, processedComments)
    }
  }

  private func preprocessComments(_ comments: [Comment]) -> [ProcessedComment] {
    return comments.map { comment in
      let processedText = comment.text != nil ? HTMLParser.stripHTML(comment.text!) : ""
      let processedReplies = comment.replies != nil ? preprocessComments(comment.replies!) : nil
      return ProcessedComment(original: comment, processedText: processedText, processedReplies: processedReplies)
    }
  }

  private func searchInProcessedStory(_ processedStory: ProcessedStory, query: String) -> SearchResult? {
    var matchedText = ""
    var contextBefore = ""
    var contextAfter = ""
    var isMatch = false
    
    let story = processedStory.original

    // Search in title
    if story.title.lowercased().contains(query) {
      isMatch = true
      if let matchRange = story.title.lowercased().range(of: query) {
        matchedText = String(story.title[matchRange])
        let beforeRange = story.title.startIndex..<matchRange.lowerBound
        let afterRange = matchRange.upperBound..<story.title.endIndex
        contextBefore = String(story.title[beforeRange]).suffix(50).description
        contextAfter = String(story.title[afterRange]).prefix(50).description
      }
    }

    // Search in text content if available
    if let plainText = processedStory.processedText, !isMatch {
      if plainText.lowercased().contains(query) {
        isMatch = true
        if let matchRange = plainText.lowercased().range(of: query) {
          matchedText = String(plainText[matchRange])
          let beforeStart = max(
            plainText.startIndex,
            plainText.index(matchRange.lowerBound, offsetBy: -50, limitedBy: plainText.startIndex)
              ?? plainText.startIndex)
          let afterEnd = min(
            plainText.endIndex,
            plainText.index(matchRange.upperBound, offsetBy: 50, limitedBy: plainText.endIndex)
              ?? plainText.endIndex)
          contextBefore = String(plainText[beforeStart..<matchRange.lowerBound])
          contextAfter = String(plainText[matchRange.upperBound..<afterEnd])
        }
      }
    }

    guard isMatch else { return nil }

    return SearchResult(
      type: .story,
      storyId: story.id,
      commentId: nil,
      title: story.title,
      content: story.text ?? "",
      author: story.by,
      timestamp: story.time,
      matchedText: matchedText,
      contextBefore: contextBefore,
      contextAfter: contextAfter
    )
  }

  private func searchInProcessedComments(story: Story, comments: [ProcessedComment], query: String) -> [SearchResult]
  {
    var results: [SearchResult] = []

    func searchRecursively(in comments: [ProcessedComment]) {
      for processedComment in comments {
        let comment = processedComment.original
        guard let author = comment.by else { continue }

        let plainText = processedComment.processedText
        if !plainText.isEmpty && plainText.lowercased().contains(query) {
          if let matchRange = plainText.lowercased().range(of: query) {
            let matchedText = String(plainText[matchRange])
            let beforeStart = max(
              plainText.startIndex,
              plainText.index(matchRange.lowerBound, offsetBy: -50, limitedBy: plainText.startIndex)
                ?? plainText.startIndex)
            let afterEnd = min(
              plainText.endIndex,
              plainText.index(matchRange.upperBound, offsetBy: 50, limitedBy: plainText.endIndex)
                ?? plainText.endIndex)
            let contextBefore = String(plainText[beforeStart..<matchRange.lowerBound])
            let contextAfter = String(plainText[matchRange.upperBound..<afterEnd])

            let result = SearchResult(
              type: .comment,
              storyId: story.id,
              commentId: comment.id,
              title: story.title,
              content: plainText,
              author: author,
              timestamp: comment.time,
              matchedText: matchedText,
              contextBefore: contextBefore,
              contextAfter: contextAfter
            )
            results.append(result)
          }
        }

        // Search in nested replies
        if let processedReplies = processedComment.processedReplies {
          searchRecursively(in: processedReplies)
        }
      }
    }

    searchRecursively(in: comments)
    return results
  }

  private func sortSearchResults(_ results: [SearchResult], query: String) -> [SearchResult] {
    return results.sorted { result1, result2 in
      let exactMatch1 = result1.matchedText.lowercased() == query
      let exactMatch2 = result2.matchedText.lowercased() == query

      if exactMatch1 && !exactMatch2 { return true }
      if exactMatch2 && !exactMatch1 { return false }

      return result1.timestamp > result2.timestamp
    }
  }
}
