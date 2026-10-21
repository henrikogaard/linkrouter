import AppKit
import SwiftUI

struct RulesPane: View {
    @EnvironmentObject private var state: AppState
    @State private var editing: Rule?
    @State private var draggingID: UUID?
    @State private var testLink = ""

    private var regularRules: [Rule] { state.rules.filter { !$0.isFallback } }
    private var fallbackRule: Rule? { state.rules.first(where: \.isFallback) }

    var body: some View {
        Form {
            Section {
                if regularRules.isEmpty {
                    Text("No rules yet. Links fall through to the default below.")
                        .foregroundStyle(.secondary)
                }
                ForEach(regularRules) { rule in
                    RuleRow(
                        rule: rule,
                        draggingID: $draggingID,
                        move: state.moveRule,
                        onEdit: { editing = rule }
                    )
                }
            } footer: {
                Text("Checked from top to bottom; the first match wins. Profiles are checked before rules.")
            }

            Section("When nothing else matches") {
                if let fallbackRule {
                    FallbackRuleRow(rule: fallbackRule) {
                        editing = fallbackRule
                    }
                }
            }

            Section("Try a link") {
                TextField("Link", text: $testLink, prompt: Text("https://github.com/…"))
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !testLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    LabeledContent("Result") {
                        switch testOutcome {
                        case .none:
                            EmptyView()
                        case .plain(let text):
                            Text(text)
                                .foregroundStyle(.secondary)
                        case .rule(let text, let id):
                            Button(text) {
                                editing = state.rules.first(where: { $0.id == id })
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editing = state.addRule()
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editing) { rule in
            RuleEditorSheet(
                rule: rule,
                onSave: state.updateRule,
                onDelete: rule.isFallback ? nil : {
                    state.removeRule(rule)
                },
                onDuplicate: rule.isFallback ? nil : {
                    state.duplicateRule(rule)
                }
            )
            .environmentObject(state)
        }
    }

    private enum TestOutcome {
        case plain(String)
        case rule(String, UUID)
    }

    private var testOutcome: TestOutcome? {
        let trimmed = testLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: candidate), url.host != nil else {
            return .plain(String(localized: "Invalid URL"))
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
            return .plain(String(localized: "Modifier held → \(destination)"))
        case .profile(let id):
            let name = state.profiles.first { $0.id == id }?.name ?? String(localized: "profile")
            return .plain(String(localized: "Matched profile \(name) → \(destination)"))
        case .rule(let id):
            let name = state.rules.first { $0.id == id }?.title ?? String(localized: "rule")
            return .rule(String(localized: "Matched rule \(name) → \(destination)"), id)
        case .fallback(let id):
            let name = state.rules.first { $0.id == id }?.title ?? String(localized: "fallback")
            return .rule(String(localized: "Fallback \(name) → \(destination)"), id)
        case .none:
            return .plain(String(localized: "No match → \(destination)"))
        }
    }
}

private struct RuleRow: View {
    @EnvironmentObject private var state: AppState
    var rule: Rule
    @Binding var draggingID: UUID?
    var move: (UUID, UUID) -> Void
    var onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(width: 16)
                .contentShape(Rectangle())
                .help("Drag to reorder")
                .onDrag {
                    draggingID = rule.id
                    return NSItemProvider(object: BrowsersPane.dragPayload(rule.id) as NSString)
                }

            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(rule.title)
                        .font(.system(size: 13))
                    Text(rule.summary(in: state))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Toggle("Enabled", isOn: enabledBinding)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .accessibilityLabel("Enable \(rule.title)")

            Menu {
                rowActions
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("Rule actions")
        }
        .onDrop(
            of: [.plainText],
            delegate: ReorderDropDelegate(
                targetID: rule.id,
                draggingID: $draggingID,
                move: move
            )
        )
        .contextMenu { rowActions }
    }

    @ViewBuilder
    private var rowActions: some View {
        Button("Edit…", action: onEdit)
        Button("Duplicate") { state.duplicateRule(rule) }
        let index = state.rules.firstIndex(where: { $0.id == rule.id }) ?? 0
        Button("Move Up") {
            guard index > 0 else { return }
            state.moveRule(id: rule.id, to: state.rules[index - 1].id)
        }
        .disabled(index == 0)
        Button("Move Down") {
            guard index + 1 < state.rules.filter({ !$0.isFallback }).count else { return }
            state.moveRule(id: rule.id, to: state.rules[index + 1].id)
        }
        .disabled(index + 1 >= state.rules.filter({ !$0.isFallback }).count)
        Divider()
        Button("Delete", role: .destructive) { state.removeRule(rule) }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { rule.enabled },
            set: { value in
                var updated = rule
                updated.enabled = value
                state.updateRule(updated)
            }
        )
    }
}

private struct FallbackRuleRow: View {
    @EnvironmentObject private var state: AppState
    var rule: Rule
    var onEdit: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.title)
                    .font(.system(size: 13))
                Text(rule.destination(in: state))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button("Edit…", action: onEdit)
        }
    }
}

private extension Rule {
    @MainActor
    func summary(in state: AppState) -> String {
        let conditions = conditions.map { $0.summary(in: state) }
        let conditionText: String
        if conditions.isEmpty {
            conditionText = String(localized: "Every link")
        } else {
            let separator: String
            switch combinator {
            case .all: separator = String(localized: "and")
            case .any: separator = String(localized: "or")
            case .none: separator = String(localized: "or")
            }
            let joined = conditions.joined(separator: " \(separator) ")
            conditionText = combinator == .none
                ? String(localized: "none of \(joined)")
                : joined
        }
        return String(localized: "\(conditionText) → \(destination(in: state))")
    }

    @MainActor
    func destination(in state: AppState) -> String {
        let kind = behaviour.kind
        if kind == .openBrowser, let id = behaviour.rowIDs.first,
           let row = state.rows.first(where: { $0.id == id }) {
            return state.title(for: row)
        }
        if kind == .promptBrowsers || kind == .openBrowsersInOrder {
            let titles = behaviour.rowIDs.compactMap { id in
                state.rows.first(where: { $0.id == id }).map { state.title(for: $0) }
            }
            if titles.isEmpty { return kind.label }
            return String(localized: "\(kind.label): \(titles.joined(separator: ", "))")
        }
        return kind.label
    }
}

private extension Condition {
    @MainActor
    func summary(in state: AppState) -> String {
        switch kind {
        case .url:
            return String(localized: "URL \(urlMatcher.label.lowercased()) \(pattern)")
        case .runningCount:
            switch (countComparator, count) {
            case (.greaterThan, 0):
                return String(localized: "Any browser is running")
            case (.lessThan, 1), (.is, 0):
                return String(localized: "No browsers are running")
            case (.greaterThan, _):
                return String(localized: "More than \(count) browsers running")
            case (.lessThan, _):
                return String(localized: "Fewer than \(count) browsers running")
            case (.is, _):
                return String(localized: "Exactly \(count) browsers running")
            case (.isNot, _):
                return String(localized: "Not exactly \(count) browsers running")
            }
        case .linkType:
            return linkKind.label
        case .sourceApp:
            let appName: String
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: pattern) {
                appName = Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? url.deletingPathExtension().lastPathComponent
            } else {
                appName = pattern
            }
            return String(localized: "From \(appName)")
        case .schedule:
            let start = Self.clockString(startMinute)
            let end = Self.clockString(endMinute)
            let weekdays = DateFormatter().shortWeekdaySymbols ?? []
            let days = self.weekdays.sorted().compactMap { day -> String? in
                guard (1...weekdays.count).contains(day) else { return nil }
                return weekdays[day - 1]
            }
            return String(localized: "\(start)–\(end) on \(days.joined(separator: ", "))")
        }
    }

    private static func clockString(_ minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
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
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Name", text: $rule.title)
                        .disabled(rule.isFallback)
                } footer: {
                    if rule.isFallback {
                        Text("Used when no profile or earlier rule matches.")
                    } else if let validationError {
                        Text(validationError)
                            .foregroundStyle(.red)
                    }
                }

                if !rule.isFallback {
                    Section("Conditions") {
                        Picker("Match", selection: $rule.combinator) {
                            ForEach(Combinator.allCases) { item in
                                Text(item.shortLabel).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)

                        ForEach($rule.conditions) { $condition in
                            conditionRow($condition)
                        }

                        Button {
                            rule.conditions.append(.url())
                        } label: {
                            Label("Add Condition", systemImage: "plus")
                        }
                        .buttonStyle(.borderless)
                    }
                }

                Section("Then") {
                    Picker("Action", selection: $rule.behaviour.kind) {
                        ForEach(Behaviour.Kind.allCases) { kind in
                            Text(kind.label).tag(kind)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if rule.behaviour.kind.needsRows {
                    Section {
                        BrowserPicker(
                            allowsMultiple: rule.behaviour.kind != .openBrowser,
                            showsOrder: rule.behaviour.kind == .openBrowsersInOrder,
                            selection: $rule.behaviour.rowIDs
                        )
                    } header: {
                        Text(rule.behaviour.kind == .openBrowser ? "Browser" : "Browsers")
                    } footer: {
                        if rule.behaviour.kind == .openBrowsersInOrder {
                            Text("Click browsers in the order they should be tried.")
                        }
                    }
                }

            }
            .formStyle(.grouped)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            editorBar
        }
        .frame(width: 560, height: 500)
    }

    private var editorBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                if let onDelete {
                    Button("Delete…", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .foregroundStyle(.red)
                }
                if let onDuplicate {
                    Button("Duplicate") {
                        onDuplicate()
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(LR.accent)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
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
                .frame(width: 120)
                TextField("Web address", text: condition.pattern, prompt: Text("github.com"))
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .runningCount:
                Picker("Comparator", selection: condition.countComparator) {
                    ForEach(CountComparator.allCases) { item in
                        Text(item.label).tag(item)
                    }
                }
                .labelsHidden()
                .accessibilityLabel("Count comparator")
                .pickerStyle(.menu)
                .frame(width: 120)
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
                .frame(maxWidth: .infinity, alignment: .leading)
            case .sourceApp:
                Picker("Matcher", selection: condition.urlMatcher) {
                    ForEach([URLMatcher.is, .isNot, .contains]) { matcher in
                        Text(matcher.label).tag(matcher)
                    }
                }
                .labelsHidden()
                .accessibilityLabel("App matcher")
                .pickerStyle(.menu)
                .frame(width: 120)
                HStack(spacing: 8) {
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
                    .frame(width: 140)
                    TextField("Sent from app", text: condition.pattern, prompt: Text("com.example.app"))
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
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
                            Toggle(isOn: weekdayBinding(condition, day: chip.day)) {
                                Text(chip.label)
                            }
                            .toggleStyle(.button)
                            .controlSize(.small)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if condition.wrappedValue.kind == .runningCount {
                Spacer(minLength: 0)
            }

            Button {
                rule.conditions.removeAll { $0.id == condition.wrappedValue.id }
            } label: {
                Image(systemName: "minus.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .disabled(rule.conditions.count < 2)
        }
    }

    private var runningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    private var weekdayChips: [(day: Int, label: String)] {
        let symbols = DateFormatter().shortWeekdaySymbols ?? []
        return [2, 3, 4, 5, 6, 7, 1].map { day in
            let label = (1...symbols.count).contains(day) ? symbols[day - 1] : ""
            return (day, label)
        }
    }

    private func weekdayBinding(_ condition: Binding<Condition>, day: Int) -> Binding<Bool> {
        Binding(
            get: { condition.wrappedValue.weekdays.contains(day) },
            set: { enabled in
                if enabled {
                    condition.wrappedValue.weekdays.insert(day)
                } else {
                    condition.wrappedValue.weekdays.remove(day)
                }
            }
        )
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
                validationError = String(localized: "Enter a web address pattern.")
                return
            }
            if condition.urlMatcher == .regex {
                do {
                    _ = try NSRegularExpression(pattern: condition.pattern)
                } catch {
                    validationError = String(localized: "Invalid regex: \(error.localizedDescription)")
                    return
                }
            }
        }
        if rule.behaviour.kind.needsRows && rule.behaviour.rowIDs.isEmpty {
            validationError = String(localized: "Choose at least one browser.")
            return
        }
        rule.title = rule.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if rule.title.isEmpty {
            rule.title = String(localized: "Untitled rule")
        }
        onSave(rule)
        dismiss()
    }
}
