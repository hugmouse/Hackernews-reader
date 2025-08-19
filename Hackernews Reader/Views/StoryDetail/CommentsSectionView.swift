import SwiftUI

struct CommentsSectionHeader: View {
  let count: Int

  var body: some View {
    HStack {
      Text("Comments (\(count))")
        .font(.headline)
      Spacer()
    }
  }
}

struct CommentsLoadingView: View {
  var body: some View {
    VStack(spacing: 12) {
      ProgressView()
      Text("Loading comments...")
        .foregroundStyle(.secondary)
        .font(.caption)
    }
    .frame(maxWidth: .infinity)
    .padding()
  }
}

struct CommentsListView: View {
  let comments: [Comment]
  let highlightedCommentId: Int?
  let searchQuery: String

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ForEach(comments, id: \.id) { comment in
        CommentView(
          comment: comment,
          level: 0,
          highlightedCommentId: highlightedCommentId,
          searchQuery: searchQuery
        )
      }
    }
  }
}
