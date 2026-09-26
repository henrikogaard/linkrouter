import SwiftUI

struct RulesPane: View {
    @EnvironmentObject private var state: AppState
    @State private var editing: Rule?
    @State private var selection: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(
                title: "Rules",
                subtitle: "First match wins. The locked row is the fallback when nothing else applies."
            )

            List {
                ForEach(state.rules) { rule in
                    RuleRow(rule: rule, isSelected: selection == rule.id) {
                        selection = rule.id
                        editing = rule
                    }
                    .contextMenu {
                        Button("Edit") {
                            selection = rule.id
                            editing = rule
                        }
                        if !rule.isFallback {
                            Button("Delete", role: .destructive) {
                                remove(rule)
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: LR.pageInset, bottom: 4, trailing: LR.pageInset))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .onMove { offsets, dest in
                    let unlocked = IndexSet(state.rules.enumerated().compactMap { $0.element.isFallback ? nil : $0.offset })
                    let filtered = IndexSet(offsets.filter { unlocked.contains($0) })
                    guard !filtered.isEmpty else { return }
                    let fallbackIndex = state.rules.firstIndex(where: \.isFallback) ?? state.rules.count
                    state.moveRules(from: filtered, to: min(dest, fallbackIndex))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(LR.pageFill)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PaneFooter {
                Button {
                    state.addRule()
                    editing = state.rules.last(where: { !$0.isFallback })
                    selection = editing?.id
                } label: {
                    Label("Add", systemImage: "plus")
                }
                Button {
                    if let selectedRule, !selectedRule.isFallback {
                        remove(selectedRule)
                    }
                } label: {
                    Label("Remove", systemImage: "minus")
                }
                .disabled(selectedRule == nil || selectedRule?.isFallback == true)
                Spacer()
            }
        }
        .sheet(item: $editing) { rule in
            RuleEditorSheet(
                rule: rule,
                onSave: { updated in
                    state.updateRule(updated)
                },
                onDelete: rule.isFallback ? nil : {
                    remove(rule)
                }
            )
            .environmentObject(state)
        }
    }

    private var selectedRule: Rule? {
        state.rules.first { $0.id == selection }
    }

    private func remove(_ rule: Rule) {
        state.removeRule(rule)
        if selection == rule.id {
            selection = nil
        }
    }
}

private struct RuleRow: View {
    @EnvironmentObject private var state: AppState
    var rule: Rule
    var isSelected: Bool
    var onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 14) {
                Image(systemName: rule.isFallback ? "lock.fill" : "line.3.horizontal")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 3) {
                    Text(rule.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                    Text(rule.behaviour.kind.label)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !rule.isFallback {
                    Toggle("Enabled", isOn: enabledBinding)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                        .tint(LR.accent)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(fill, in: RoundedRectangle(cornerRadius: LR.rowRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LR.rowRadius, style: .continuous)
                    .strokeBorder(isSelected ? LR.accent.opacity(0.45) : LR.hairline, lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var fill: Color {
        isSelected ? LR.accent.opacity(0.10) : LR.rowFill
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { rule.enabled },
            set: { value in
                var next = rule
                next.enabled = value
                state.updateRule(next)
            }
        )
    }
}

struct RuleEditorSheet: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State var rule: Rule
    var onSave: (Rule) -> Void
    var onDelete: (() -> Void)?
    @State private var validationError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(rule.isFallback ? "Fallback" : "Rule")
                .font(.system(size: 18, weight: .semibold))

            EditorSection(title: "Name") {
                TextField("Name", text: $rule.title)
                    .textFieldStyle(.roundedBorder)
                    .disabled(rule.isFallback)
            }

            if rule.isFallback {
                Text("Used when no profile and no earlier rule matches.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else {
                EditorSection(title: "Match") {
                    Picker("Match", selection: $rule.combinator) {
                        ForEach(Combinator.allCases) { item in
                            Text(item.shortLabel).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                EditorSection(title: "Conditions") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach($rule.conditions) { $condition in
                            conditionRow($condition)
                        }
                        Button {
                            rule.conditions.append(.url())
                        } label: {
                            Label("Add condition", systemImage: "plus")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            EditorSection(title: "Then") {
                Picker("Then", selection: $rule.behaviour.kind) {
                    ForEach(Behaviour.Kind.allCases) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if rule.behaviour.kind.needsRows {
                EditorSection(
                    title: rule.behaviour.kind == .openBrowser ? "Browser" : "Browsers",
                    footnote: rule.behaviour.kind == .openBrowsersInOrder
                        ? "Click in the order they should try."
                        : nil
                ) {
                    ScrollView {
                        BrowserPicker(
                            allowsMultiple: rule.behaviour.kind != .openBrowser,
                            selection: $rule.behaviour.rowIDs
                        )
                    }
                    .frame(maxHeight: 220)
                }
            }

            if let validationError {
                Text(validationError)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }

            Spacer(minLength: 0)

            HStack {
                if let onDelete {
                    Button("Delete", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(LR.accent)
            }
        }
        .padding(24)
        .frame(width: 540, height: 640)
    }

    private func conditionRow(_ condition: Binding<Condition>) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Picker("Type", selection: condition.kind) {
                ForEach(Condition.Kind.allCases) { kind in
                    Text(kind.label).tag(kind)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 150, alignment: .leading)

            switch condition.wrappedValue.kind {
            case .url:
                Picker("Matcher", selection: condition.urlMatcher) {
                    ForEach(URLMatcher.allCases) { matcher in
                        Text(matcher.label).tag(matcher)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 110)
                TextField("github.com", text: condition.pattern)
                    .textFieldStyle(.roundedBorder)
            case .runningCount:
                Picker("Comparator", selection: condition.countComparator) {
                    ForEach(CountComparator.allCases) { item in
                        Text(item.label).tag(item)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 140)
                Stepper(value: condition.count, in: 0...10) {
                    Text("\(condition.wrappedValue.count)")
                        .monospacedDigit()
                        .frame(width: 24)
                }
            case .linkType:
                Picker("Kind", selection: condition.linkKind) {
                    ForEach(LinkKind.allCases) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            Button {
                rule.conditions.removeAll { $0.id == condition.wrappedValue.id }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(rule.conditions.count < 2)
        }
        .padding(10)
        .background(LR.rowFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func save() {
        for condition in rule.conditions where condition.kind == .url {
            if condition.pattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                validationError = "Enter a web address pattern."
                return
            }
            if condition.urlMatcher == .regex {
                do {
                    _ = try NSRegularExpression(pattern: condition.pattern)
                } catch {
                    validationError = "Invalid regex: \(error.localizedDescription)"
                    return
                }
            }
        }
        if rule.behaviour.kind.needsRows && rule.behaviour.rowIDs.isEmpty {
            validationError = "Choose at least one browser."
            return
        }
        rule.title = rule.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if rule.title.isEmpty {
            rule.title = "Untitled rule"
        }
        onSave(rule)
        dismiss()
    }
}
