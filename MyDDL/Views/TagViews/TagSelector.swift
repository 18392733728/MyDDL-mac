import SwiftUI

struct TagSelector: View {
    @ObservedObject var tagManager = TagManager.shared
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var selectedTags: [String]

    @State private var showAddTagSheet = false
    @State private var newTagName = ""
    @State private var newTagColor = Tag.presetColors.first ?? "#5B8DEF"

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // 已选标签
            if !selectedTags.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("已选标签")
                        .font(DesignSystem.Fonts.caption)
                        .foregroundColor(themeManager.current.textSecondary)

                    FlowLayout(spacing: DesignSystem.Spacing.sm) {
                        ForEach(selectedTags, id: \.self) { tagName in
                            TagChip(
                                tagName: tagName,
                                isSelected: true,
                                onTap: {
                                    removeTag(tagName)
                                }
                            )
                        }
                    }
                }
                .padding(DesignSystem.Spacing.md)
                .background(themeManager.current.secondaryBackground)
                .cornerRadius(DesignSystem.Radius.medium)
            }

            // 可选标签
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Text("选择标签")
                        .font(DesignSystem.Fonts.caption)
                        .foregroundColor(themeManager.current.textSecondary)

                    Spacer()

                    Button(action: { showAddTagSheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("新建")
                        }
                        .font(DesignSystem.Fonts.caption)
                        .foregroundColor(DesignSystem.Colors.accent)
                    }
                    .buttonStyle(.plain)
                }

                let availableTags = tagManager.tags.filter { tag in
                    !selectedTags.contains(tag.name)
                }

                if availableTags.isEmpty {
                    Text("暂无可用标签")
                        .font(DesignSystem.Fonts.body)
                        .foregroundColor(themeManager.current.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(DesignSystem.Spacing.lg)
                } else {
                    FlowLayout(spacing: DesignSystem.Spacing.sm) {
                        ForEach(availableTags) { tag in
                            TagChip(
                                tagName: tag.name,
                                color: tag.color,
                                isSelected: false,
                                onTap: {
                                    addTag(tag.name)
                                }
                            )
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddTagSheet) {
            AddTagSheet(
                tagName: $newTagName,
                tagColor: $newTagColor,
                onSave: {
                    let tag = Tag(name: newTagName, colorHex: newTagColor)
                    tagManager.addTag(tag)
                    addTag(tag.name)
                    newTagName = ""
                    showAddTagSheet = false
                }
            )
        }
    }

    private func addTag(_ tagName: String) {
        if !selectedTags.contains(tagName) {
            selectedTags.append(tagName)
        }
    }

    private func removeTag(_ tagName: String) {
        selectedTags.removeAll { $0 == tagName }
    }
}

// MARK: - Tag Chip
struct TagChip: View {
    @EnvironmentObject var themeManager: ThemeManager
    let tagManager = TagManager.shared

    let tagName: String
    var color: Color? = nil
    let isSelected: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Text(tagName)
                    .font(DesignSystem.Fonts.caption)

                if isSelected {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(chipBackground)
            .foregroundColor(chipForeground)
            .cornerRadius(DesignSystem.Radius.large)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.large)
                    .strokeBorder(chipBorder, lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var tagColor: Color {
        if let providedColor = color {
            return providedColor
        }

        if let tag = tagManager.getTag(by: tagName) {
            return tag.color
        }

        return DesignSystem.Colors.accent
    }

    private var chipBackground: Color {
        if isSelected {
            return tagColor.opacity(0.2)
        }
        return themeManager.current.cardBackground
    }

    private var chipForeground: Color {
        if isSelected {
            return tagColor
        }
        return themeManager.current.textPrimary
    }

    private var chipBorder: Color {
        if isSelected {
            return tagColor.opacity(0.5)
        }
        return themeManager.current.textTertiary.opacity(0.3)
    }
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowLayoutResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowLayoutResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }

    struct FlowLayoutResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    // 换行
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))

                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// MARK: - Add Tag Sheet
struct AddTagSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager

    @Binding var tagName: String
    @Binding var tagColor: String
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Text("新建标签")
                .font(DesignSystem.Fonts.headline)
                .foregroundColor(themeManager.current.textPrimary)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("标签名称")
                    .font(DesignSystem.Fonts.caption)
                    .foregroundColor(themeManager.current.textSecondary)

                TextField("输入标签名称", text: $tagName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("标签颜色")
                    .font(DesignSystem.Fonts.caption)
                    .foregroundColor(themeManager.current.textSecondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: DesignSystem.Spacing.sm) {
                    ForEach(Tag.presetColors, id: \.self) { colorHex in
                        ColorPickerCell(
                            color: Color(hex: colorHex) ?? Color.blue,
                            isSelected: tagColor == colorHex,
                            onTap: { tagColor = colorHex }
                        )
                    }
                }
            }

            HStack(spacing: DesignSystem.Spacing.md) {
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(themeManager.current.textSecondary)

                Button("保存") {
                    onSave()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(tagName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.top, DesignSystem.Spacing.md)
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(width: 400)
        .background(themeManager.current.background)
    }
}

// MARK: - Color Picker Cell
struct ColorPickerCell: View {
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Circle()
                .fill(color)
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white, lineWidth: isSelected ? 3 : 0)
                )
                .overlay(
                    Circle()
                        .strokeBorder(Color.black.opacity(0.1), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
