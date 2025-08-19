import SwiftUI

struct StoryRowView: View {
    let story: Story
    let isRead: Bool
    let isReading: Bool
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(story.title)
                .font(.headline)
                .lineLimit(3)
            
            HStack(spacing: 4) {
                Text("\(story.score) points")
                
                HStack(spacing: 2) {
                    Text("by")
                    Button(story.by) {
                        openWindow(id: "userProfile", value: story.by)
                    }
                    .fontWeight(.semibold)
                    .buttonStyle(.link)
                    .accessibilityLabel("View profile for \(story.by)")
                }
                
                Text(timeAgo(from: story.time))
                
                if story.descendants != nil {
                    Text("\(story.descendants ?? 0) comments")
                }
                
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .opacity(isRead && !isReading ? 0.8 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(story.title), by \(story.by), \(story.score) points, \(timeAgo(from: story.time))\(story.descendants != nil ? ", \(story.descendants!) comments" : "")"
        )
    }
    
    private func timeAgo(from timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    let sampleStory = Story(
        id: 1,
        title: "Sample Story Title That Could Be Very Long and Span Multiple Lines",
        by: "username",
        time: Int(Date().timeIntervalSince1970) - 3600,
        score: 42,
        descendants: 15,
        url: "https://example.com",
        text: nil,
        kids: [2, 3, 4]
    )
    
    List {
        StoryRowView(story: sampleStory, isRead: false, isReading: false)
        StoryRowView(story: sampleStory, isRead: true, isReading: false)
    }
    .listStyle(.sidebar)
}
