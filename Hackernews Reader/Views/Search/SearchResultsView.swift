import SwiftUI

struct SearchResultsView: View {
  let searchResults: [SearchResult]
  let onResultSelected: (SearchResult) -> Void
  @State private var selectedSearchResult: SearchResult?

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text("\(searchResults.count) results")
          .font(.caption)
          .foregroundColor(.secondary)
          .padding(.horizontal)
      }
      .padding(.bottom, 4)

      List(selection: $selectedSearchResult) {
        ForEach(searchResults) { result in
          SearchResultRowView(result: result)
            .onTapGesture {
              selectedSearchResult = result
              onResultSelected(result)
            }
            .tag(result)
        }
      }
      .listStyle(.sidebar)
    }
  }
}

struct SearchResultRowView: View {
  let result: SearchResult

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Image(systemName: result.type == .story ? "doc.text" : "bubble.left")
          .foregroundColor(result.type == .story ? .blue : .green)
          .font(.caption)
          .accessibilityHidden(true)

        Text(result.type == .story ? "Story" : "Comment")
          .font(.caption)
          .foregroundColor(.secondary)

        Spacer()

        Text(TimeFormatter.timeAgoString(from: result.timestamp))
          .font(.caption)
          .foregroundColor(.secondary)
      }

      Text(result.title)
        .font(.headline)
        .lineLimit(1)

      HStack(spacing: 2) {
        if !result.contextBefore.isEmpty {
          Text(result.contextBefore)
            .font(.body)
            .foregroundColor(.secondary)
        }

        Text(result.matchedText)
          .font(.body)
          .fontWeight(.semibold)
          .background(Color.yellow.opacity(0.7))
          .cornerRadius(2)

        if !result.contextAfter.isEmpty {
          Text(result.contextAfter)
            .font(.body)
            .foregroundColor(.secondary)
        }
      }
      .lineLimit(1)

      Text("by \(result.author)")
        .font(.caption)
        .foregroundColor(.secondary)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "\(result.type == .story ? "Story" : "Comment"): \(result.title), by \(result.author), \(TimeFormatter.timeAgoString(from: result.timestamp)). Matched text: \(result.matchedText)"
    )
    .accessibilityHint("Tap to view this \(result.type == .story ? "story" : "comment")")
    .padding(.vertical, 4)
    .contentShape(Rectangle())
    .cornerRadius(8)
  }
}
