import AppKit
import SwiftUI

struct RulesPane: View {
    @EnvironmentObject private var state: AppState
    @State private var editing: Rule?
    @State private var selection: UUID?
    @State private var testLink = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(
                title: "Rules",
                subtitle: "First match wins. The locked row is the fallback when nothing else applies."
            )

            List {
                ForEach(Array(state.rules.enumerated()), id: \.element.id) { index, rule in
                    RuleRow(rule: rule, index: index, isSelected: selection == rule.id) {
                        selection = rule.id
                        editing = rule
                    }
                    .contextMenu {
                        Button("Edit") {
                            selection = rule.id
                            editing = rule
                        }
                        Button("Duplicate") {
                            state.duplicateRule(rule)
                        }
                        if !rule.isFallback {
                            Toggle("Enabled", isOn: enabledBinding(rule))
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

            VStack(alignment: .leading, spacing: 6) {
                TextField("Test a link, e.g. https://github.com/foo", text: $testLink)
                    .textFieldStyle(.roundedBorder)
                switch testOutcome {
                case .none:
                    EmptyView()
                case .plain(let text):
                    Text(text)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                case .rule(let text, let id):
                    Button {
                        selection = id
                    } label: {
                        Text(text)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                            .underline()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, LR.pageInset)
            .padding(.vertical, 8)
        }
        .background(LR.pageFill)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PaneFooter {
                Button {
                    let rule = state.addRule()
                    editing = rule
                    selection = rule.id
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
                },
                onDuplicate: {
                    state.duplicateRule(rule)
                }
            )
            .environmentObject(state)
        }
    }

    private var selectedRule: Rule? {
        state.rules.first { $0.id == selection }
    }

    private enum TestOutcome {
        case plain(String)
        case rule(String, UUID)
    }

    private func enabledBinding(_ rule: Rule) -> Binding<Bool> {
        Binding(
            get: { rule.enabled },
            set: { value in
                var next = rule
                next.enabled = value
                state.updateRule(next)
            }
        )
    }

    private var testOutcome: TestOutcome? {
        let trimmed = testLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: candidate), url.host != nil else {
            return .plain("Invalid URL")
        }
        let explanation = RuleEngine.explain(
            link: IncomingLink(url: url),
            profiles: state.profiles,
            rules: state.rules,
            runningCount: state.runningCount,
            modifierForcePrompt: false
        )
        let destination = state.describe(explanation.result)
        switch explanation.source {
        case .modifier:
            return .plain("Modifier held → \(destination)")
        case .profile(let id):
            let name = state.profiles.first { $0.id == id }?.name ?? "profile"
            return .plain("Matched profile \(name) → \(destination)")
        case .rule(let id):
            let name = state.rules.first { $0.id == id }?.title ?? "rule"
            return .rule("Matched rule \(name) → \(destination)", id)
        case .fallback(let id):
            let name = state.rules.first { $0.id == id }?.title ?? "fallback"
            return .rule("Fallback \(name) → \(destination)", id)
        case .none:
            return .plain("No match → \(destination)")
        }
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
    var index: Int
    var isSelected: Bool
    var onEdit: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onEdit) {
                HStack(spacing: 14) {
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .frame(width: 20)
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
                }
                .padding(.leading, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            if !rule.isFallback {
                Toggle("Enabled", isOn: enabledBinding)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
                    .accessibilityLabel("Enable \(rule.title)")
                    .tint(LR.accent)
                    .padding(.trailing, 14)
            } else {
                Spacer().frame(width: 14)
            }
        }
        .background(fill, in: RoundedRectangle(cornerRadius: LR.rowRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LR.rowRadius, style: .continuous)
                .strokeBorder(isSelected ? LR.selectionStroke : LR.hairline, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var fill: Color {
        isSelected ? LR.selectionFill : LR.rowFill
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
    var onDuplicate: (() -> Void)?
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
                    .accessibilityLabel("Match")
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
                .accessibilityLabel("Then")
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
                if let onDuplicate {
                    Button("Duplicate") {
                        onDuplicate()
                        dismiss()
                    }
                    .buttonStyle(.plain)
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
            .accessibilityLabel("Condition type")
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
                .accessibilityLabel("URL matcher")
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
                .accessibilityLabel("Count comparator")
                .pickerStyle(.menu)
                .frame(width: 140)
                Stepper(value: condition.count, in: 0...10) {
                    Text("\(condition.wrappedValue.count)")
                        .monospacedDigit()
                        .frame(width: 24)
                }
                .accessibilityLabel("Running browsers count")
            case .linkType:
                Picker("Kind", selection: condition.linkKind) {
                    ForEach(LinkKind.allCases) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .labelsHidden()
                .accessibilityLabel("Link kind")
                .pickerStyle(.menu)
            case .sourceApp:
                Picker("Matcher", selection: condition.urlMatcher) {
                    ForEach([URLMatcher.is, .isNot, .contains]) { matcher in
                        Text(matcher.label).tag(matcher)
                    }
                }
                .labelsHidden()
                .accessibilityLabel("App matcher")
                .pickerStyle(.menu)
                .frame(width: 110)
                Picker("App", selection: condition.pattern) {
                    Text("Choose…").tag("")
                    ForEach(runningApps, id: \.bundleIdentifier) { app in
                        Text("\(app.localizedName ?? "?") — \(app.bundleIdentifier ?? "")")
                            .tag(app.bundleIdentifier ?? "")
                    }
                }
                .labelsHidden()
                .accessibilityLabel("Source app")
                .pickerStyle(.menu)
                .frame(width: 210)
                TextField("com.example.app", text: condition.pattern)
                    .textFieldStyle(.roundedBorder)
            case .schedule:
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        DatePicker("From", selection: minuteBinding(condition, \.startMinute), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .accessibilityLabel("From time")
                        DatePicker("Until", selection: minuteBinding(condition, \.endMinute), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .accessibilityLabel("Until time")
                    }
                    HStack(spacing: 4) {
                        ForEach(weekdayChips, id: \.day) { chip in
                            let on = condition.wrappedValue.weekdays.contains(chip.day)
                            Text(chip.label)
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(on ? LR.selectionFill : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(on ? LR.selectionStroke : LR.hairline)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if on {
                                        condition.wrappedValue.weekdays.remove(chip.day)
                                    } else {
                                        condition.wrappedValue.weekdays.insert(chip.day)
                                    }
                                }
                                .accessibilityLabel(chip.label)
                                .accessibilityValue(on ? "On" : "Off")
                                .accessibilityAddTraits(.isButton)
                        }
                    }
                }
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

    private var runningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    private var weekdayChips: [(day: Int, label: String)] {
        [(2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"), (6, "Fri"), (7, "Sat"), (1, "Sun")]
    }

    private func minuteBinding(_ condition: Binding<Condition>, _ keyPath: WritableKeyPath<Condition, Int>) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    from: DateComponents(
                        hour: condition.wrappedValue[keyPath: keyPath] / 60,
                        minute: condition.wrappedValue[keyPath: keyPath] % 60
                    )
                ) ?? .now
            },
            set: { date in
                condition.wrappedValue[keyPath: keyPath] =
                    Calendar.current.component(.hour, from: date) * 60
                    + Calendar.current.component(.minute, from: date)
            }
        )
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
