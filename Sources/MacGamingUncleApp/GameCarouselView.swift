import IndieCore
import SwiftUI

struct GameCarouselView<Item: Identifiable, Card: View>: View where Item.ID: Sendable {
    let title: String
    let items: [Item]
    let cardWidth: CGFloat
    let card: (Item) -> Card
    @State private var leadingID: Item.ID?
    @State private var pageSize = 3

    init(title: String, items: [Item], cardWidth: CGFloat, @ViewBuilder card: @escaping (Item) -> Card) {
        self.title = title
        var seen = Set<Item.ID>()
        self.items = items.filter { seen.insert($0.id).inserted }
        self.cardWidth = cardWidth
        self.card = card
    }

    private var index: Int { items.firstIndex { $0.id == leadingID } ?? 0 }
    private var lastPageIndex: Int { max(0, items.count - pageSize) }

    var body: some View {
        let measuredCardWidth = cardWidth
        return VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text(title).font(.system(size: 19, weight: .semibold))
                Spacer()
                Text(L("\(items.count) 款")).font(.caption).foregroundStyle(IndiePalette.secondaryText)
                Button { move(-pageSize) } label: { Image(systemName: "chevron.left") }
                    .disabled(index == 0).help(L("上一组游戏")).accessibilityLabel(L("上一组游戏"))
                Button { move(pageSize) } label: { Image(systemName: "chevron.right") }
                    .disabled(index >= lastPageIndex).help(L("下一组游戏")).accessibilityLabel(L("下一组游戏"))
            }
            .buttonStyle(.bordered)
            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(items) { item in card(item).frame(width: cardWidth).id(item.id) }
                }
                .scrollTargetLayout().padding(.vertical, 10)
            }
            .frame(maxWidth: .infinity)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $leadingID, anchor: .leading)
            .scrollIndicators(.visible)
            .onGeometryChange(for: Int.self) { max(1, Int(($0.size.width + 14) / (measuredCardWidth + 14))) } action: { pageSize = $0 }
        }
        .onChange(of: items.map(\.id)) { _, ids in
            if !ids.contains(where: { $0 == leadingID }) { leadingID = ids.first }
        }
    }

    private func move(_ offset: Int) {
        guard !items.isEmpty else { return }
        let target = min(max(0, index + offset), lastPageIndex)
        withAnimation(.easeInOut(duration: 0.25)) { leadingID = items[target].id }
    }
}
