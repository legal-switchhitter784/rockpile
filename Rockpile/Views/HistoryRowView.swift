import SwiftUI

/// 足迹历史行 — 可展开显示 token 明细
///
/// 折叠状态（默认）：时间 · 时长 · tokens + 工具列表
/// 展开状态（点击后）：token 明细 (input/output/cache) + 上下文使用率
struct HistoryRowView: View {
    let record: SessionRecord
    @Binding var expandedRecordId: UUID?

    private var isExpanded: Bool {
        expandedRecordId == record.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.xxs) {
            // Line 1: creature icon · time · duration · tokens
            HStack(spacing: DS.Space.sm) {
                Text(record.resolvedCreatureType.icon)
                    .font(DS.Font.caption)

                Text(record.localizedSmartTimeText)
                    .font(DS.Font.monoSmall)
                    .foregroundColor(DS.TextColor.tertiary)

                Text(record.localizedDurationText)
                    .font(DS.Font.secondary)
                    .foregroundColor(DS.TextColor.secondary)

                Spacer()

                if record.totalTokens > 0 {
                    Text(TokenTracker.formatTokens(record.totalTokens))
                        .font(DS.Font.mono)
                        .foregroundColor(DS.Semantic.success)
                }

                // Expand indicator
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(DS.Font.tiny)
                    .foregroundColor(DS.TextColor.muted)
            }

            // Line 2: tool names (if any)
            if !record.toolNames.isEmpty {
                HStack(spacing: DS.Space.xs) {
                    Image(systemName: "wrench")
                        .font(DS.Font.tiny)
                        .foregroundColor(DS.Semantic.toolCall.opacity(DS.Opacity.secondary))
                    Text(record.toolSummary)
                        .font(DS.Font.secondary)
                        .foregroundColor(DS.TextColor.tertiary)
                    if record.toolCallCount > record.toolNames.count {
                        Text("\u{00d7}\(record.toolCallCount)")
                            .font(DS.Font.monoSmall)
                            .foregroundColor(DS.TextColor.muted)
                    }
                }
                .padding(.leading, DS.Space.xxs)
            }

            // Expanded: token breakdown detail
            if isExpanded {
                tokenDetailView
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, DS.Space.xs)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedRecordId = isExpanded ? nil : record.id
            }
        }
        .accessibilityLabel("\(L10n.s(record.resolvedCreatureType.displayNameKey)), \(record.localizedSmartTimeText), \(record.localizedDurationText)")
        .accessibilityHint(isExpanded ? L10n.s("dash.tapCollapse") : L10n.s("dash.tapDetail"))
    }

    // MARK: - Token Detail (Expanded)

    @ViewBuilder
    private var tokenDetailView: some View {
        if record.hasTokenBreakdown {
            HStack(alignment: .top, spacing: 0) {
                // Left accent bar
                RoundedRectangle(cornerRadius: 1)
                    .fill(DS.Semantic.info.opacity(DS.Opacity.tertiary))
                    .frame(width: 2)
                    .padding(.vertical, DS.Space.xxs)

                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    // Model name (if available)
                    if let model = record.modelName {
                        detailRow(label: L10n.s("dash.model"), value: model)
                    }

                    // Token breakdown grid
                    HStack(spacing: DS.Space.lg) {
                        if let input = record.inputTokens {
                            detailPair(label: L10n.s("dash.input"), value: TokenTracker.formatTokens(input))
                        }
                        if let output = record.outputTokens {
                            detailPair(label: L10n.s("dash.output"), value: TokenTracker.formatTokens(output))
                        }
                    }

                    HStack(spacing: DS.Space.lg) {
                        if let cacheRead = record.cacheReadTokens {
                            detailPair(label: L10n.s("dash.cacheRead"), value: TokenTracker.formatTokens(cacheRead))
                        }
                        if let cacheWrite = record.cacheCreationTokens {
                            detailPair(label: L10n.s("dash.cacheWrite"), value: TokenTracker.formatTokens(cacheWrite))
                        }
                    }
                }
                .padding(.leading, DS.Space.sm)
            }
            .padding(.top, DS.Space.xs)
        } else {
            // Old records without breakdown
            HStack(alignment: .top, spacing: 0) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(DS.TextColor.muted)
                    .frame(width: 2)
                    .padding(.vertical, DS.Space.xxs)

                Text(L10n.s("dash.noDetail"))
                    .font(DS.Font.secondary)
                    .foregroundColor(DS.TextColor.muted)
                    .padding(.leading, DS.Space.sm)
            }
            .padding(.top, DS.Space.xs)
        }
    }

    // MARK: - Detail Helpers

    private func detailRow(label: String, value: String) -> some View {
        HStack(spacing: DS.Space.sm) {
            Text(label)
                .font(DS.Font.monoSmall)
                .foregroundColor(DS.TextColor.tertiary)
                .frame(width: 40, alignment: .trailing)
            Text(value)
                .font(DS.Font.mono)
                .foregroundColor(DS.TextColor.secondary)
        }
    }

    private func detailPair(label: String, value: String) -> some View {
        HStack(spacing: DS.Space.xxs) {
            Text(label)
                .font(DS.Font.monoSmall)
                .foregroundColor(DS.TextColor.tertiary)
            Text(value)
                .font(DS.Font.mono)
                .foregroundColor(DS.TextColor.primary)
        }
    }
}
