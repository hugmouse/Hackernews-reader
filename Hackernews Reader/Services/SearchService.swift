import Foundation

class SearchService {

    func performSearch(
        query: String,
        stories: [Story],
        commentsData: [(Story, [Comment])]
    ) -> [SearchResult] {
        let storyResults = stories.compactMap { searchInStory($0, query: query) }
        
        let commentResults = commentsData.flatMap { (story, comments) in
            searchInComments(story: story, comments: comments, query: query)
        }
        
        return storyResults + commentResults
    }

    private func findMatchContext(
        in source: String,
        for query: String
    ) -> (matched: String, before: String, after: String)? {
        guard let matchRange = source.range(of: query, options: .caseInsensitive) else {
            return nil
        }

        let contextRadius = 50
        let matchedText = String(source[matchRange])

        let beforeStartIndex = source.index(
            matchRange.lowerBound,
            offsetBy: -contextRadius,
            limitedBy: source.startIndex) ?? source.startIndex
        let contextBefore = String(source[beforeStartIndex..<matchRange.lowerBound])

        let afterEndIndex = source.index(
            matchRange.upperBound,
            offsetBy: contextRadius,
            limitedBy: source.endIndex) ?? source.endIndex
        let contextAfter = String(source[matchRange.upperBound..<afterEndIndex])

        return (matchedText, contextBefore, contextAfter)
    }

    // Search in title, then text
    private func searchInStory(_ story: Story, query: String) -> SearchResult? {

        if let match = findMatchContext(in: story.title, for: query) {
            return SearchResult(
                type: .story, storyId: story.id, commentId: nil,
                title: story.title, content: story.text ?? "", author: story.by,
                timestamp: story.time, matchedText: match.matched,
                contextBefore: match.before, contextAfter: match.after
            )
        }

    
        if let text = story.text, let match = findMatchContext(in: text, for: query) {
            return SearchResult(
                type: .story, storyId: story.id, commentId: nil,
                title: story.title, content: text, author: story.by,
                timestamp: story.time, matchedText: match.matched,
                contextBefore: match.before, contextAfter: match.after
            )
        }

        return nil
    }

    private func searchInComments(story: Story, comments: [Comment], query: String) -> [SearchResult] {
        var results: [SearchResult] = []
        var queue = comments

        while !queue.isEmpty {
            let comment = queue.removeFirst()
            
            if let text = comment.text,
               let author = comment.by,
               let match = findMatchContext(in: text, for: query) {
                results.append(SearchResult(
                    type: .comment, storyId: story.id, commentId: comment.id,
                    title: story.title, content: text, author: author,
                    timestamp: comment.time, matchedText: match.matched,
                    contextBefore: match.before, contextAfter: match.after
                ))
            }

            if let replies = comment.replies {
                queue.append(contentsOf: replies)
            }
        }
        return results
    }
}
