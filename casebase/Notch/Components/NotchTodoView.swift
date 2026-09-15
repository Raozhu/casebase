import SwiftUI

struct NotchTodoListView: View {
    @ObservedObject var viewModel: NotchViewModel
    let isMeasuring: Bool

    @ViewBuilder
    var body: some View {
        let content = VStack(alignment: .leading, spacing: 16) {
            header

            VStack(alignment: .leading, spacing: 10) {
                statusFilters
                quadrantFilters
            }

            if viewModel.isTodoLoading {
                statusView(TodoCopy.loading)
            } else if let message = viewModel.todoErrorMessage, !message.isEmpty {
                errorView(message)
            } else if viewModel.visibleTodos.isEmpty && viewModel.staleTodos.isEmpty {
                emptyView
            } else {
                if isMeasuring {
                    todoSections
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        todoSections
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }

            if !isMeasuring, viewModel.visibleTodos.isEmpty && viewModel.staleTodos.isEmpty {
                Spacer(minLength: 0)
            }

            footer
        }

        if isMeasuring {
            content
                .frame(maxWidth: .infinity, alignment: .topLeading)
        } else {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(TodoCopy.title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)

            if viewModel.openTodoCount > 0 {
                NotchPixelCountBadge(
                    text: viewModel.openTodoCount >= 10 ? "9+" : "\(viewModel.openTodoCount)",
                    tone: .neutral
                )
            }

            Spacer()
            NotchBackIconButton(action: viewModel.closeTodos)
        }
    }

    private var footer: some View {
        HStack {
            Spacer(minLength: 0)

            LibraryActionTileButton(
                icon: .check,
                title: TodoCopy.add,
                action: viewModel.openNewTodo
            )
            .frame(width: LibraryActionTileButton.standardWidth)
        }
    }

    private var statusFilters: some View {
        HStack(spacing: 8) {
            TodoFilterButton(
                title: TodoCopy.open,
                isSelected: !viewModel.todoShowsCompleted,
                action: { viewModel.setTodoShowsCompleted(false) }
            )
            TodoFilterButton(
                title: TodoCopy.completed,
                isSelected: viewModel.todoShowsCompleted,
                action: { viewModel.setTodoShowsCompleted(true) }
            )
            Spacer(minLength: 0)
        }
    }

    private var quadrantFilters: some View {
        HStack(spacing: 7) {
            TodoQuadrantFilterButton(
                title: TodoCopy.allQuadrants,
                color: Color.white.opacity(0.74),
                isSelected: viewModel.todoQuadrantFilter == nil,
                action: { viewModel.setTodoQuadrantFilter(nil) }
            )

            ForEach(TodoQuadrant.allCases) { quadrant in
                TodoQuadrantFilterButton(
                    title: TodoCopy.shortQuadrant(quadrant),
                    color: TodoPalette.color(for: quadrant),
                    isSelected: viewModel.todoQuadrantFilter == quadrant,
                    action: { viewModel.setTodoQuadrantFilter(quadrant) }
                )
            }
        }
    }

    private var todoSections: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            if !viewModel.staleTodos.isEmpty {
                staleTodoSection
            }

            LazyVStack(spacing: 14) {
                ForEach(viewModel.visibleTodos) { todo in
                    TodoRow(todo: todo, viewModel: viewModel)
                }
            }
        }
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var staleTodoSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                NotchPixelIconView(icon: .refresh, color: Color.white.opacity(0.72), size: 12)
                Text(TodoCopy.needsCleanup)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text(TodoCopy.needsCleanupDetail)
                .font(.system(size: 10))
                .foregroundStyle(Color.white.opacity(0.48))

            ForEach(viewModel.staleTodos) { todo in
                StaleTodoCard(todo: todo, viewModel: viewModel)
            }
        }
    }

    private var emptyView: some View {
        LibraryGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(viewModel.todoShowsCompleted ? TodoCopy.noCompletedTitle : TodoCopy.emptyTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)

                Text(viewModel.todoShowsCompleted ? TodoCopy.noCompletedDetail : TodoCopy.emptyDetail)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statusView(_ message: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
                .tint(.white)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.68))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func errorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(Color(red: 1.0, green: 0.58, blue: 0.58))
                .fixedSize(horizontal: false, vertical: true)

            LibraryActionTileButton(
                icon: .refresh,
                title: TodoCopy.retry,
                action: viewModel.openTodos
            )
            .frame(width: LibraryActionTileButton.standardWidth)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NotchTodoEditorView: View {
    @ObservedObject var viewModel: NotchViewModel
    let isMeasuring: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if isMeasuring {
                editorFields
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    editorFields
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            actionBar
        }
        .frame(maxWidth: .infinity, maxHeight: isMeasuring ? nil : .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(viewModel.isEditingExistingTodo ? TodoCopy.editTitle : TodoCopy.newTitle)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
            Spacer()
            NotchBackIconButton(action: viewModel.closeTodoEditor)
        }
    }

    private var editorFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel(TodoCopy.todoTitle)
                TextField(TodoCopy.titlePlaceholder, text: $viewModel.todoDraftTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(TodoInputBackground())
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel(TodoCopy.sources)
                TodoSourcePicker(viewModel: viewModel)

                if !viewModel.todoDraftSourceRecordIDs.isEmpty {
                    TextField(TodoCopy.sourceReasonPlaceholder, text: $viewModel.todoDraftSourceReason)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .background(TodoInputBackground())
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel(TodoCopy.detail)
                TextEditor(text: $viewModel.todoDraftDetail)
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(height: 72)
                    .background(TodoInputBackground())
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel(TodoCopy.quadrant)
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())],
                    spacing: 8
                ) {
                    ForEach(TodoQuadrant.allCases) { quadrant in
                        TodoQuadrantChoice(
                            quadrant: quadrant,
                            isSelected: viewModel.todoDraftQuadrant == quadrant,
                            action: { viewModel.todoDraftQuadrant = quadrant }
                        )
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $viewModel.todoDraftHasDueDate) {
                    Text(TodoCopy.dueDate)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.78))
                }
                .toggleStyle(.switch)
                .controlSize(.small)

                if viewModel.todoDraftHasDueDate {
                    TodoDateTimePicker(selection: $viewModel.todoDraftDueAt)
                }
            }

            if let message = viewModel.todoErrorMessage, !message.isEmpty {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 1.0, green: 0.58, blue: 0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            if viewModel.isEditingExistingTodo {
                LibraryActionTileButton(
                    icon: .trash,
                    title: TodoCopy.delete,
                    isDestructive: true,
                    action: viewModel.openTodoDeleteConfirmation
                )
                .frame(width: LibraryActionTileButton.standardWidth)
            }

            Spacer(minLength: 0)

            LibraryActionTileButton(
                icon: .check,
                title: viewModel.isTodoSaving ? TodoCopy.saving : TodoCopy.save,
                action: viewModel.saveTodoDraft
            )
            .frame(width: LibraryActionTileButton.standardWidth)
            .disabled(!viewModel.canSaveTodoDraft || viewModel.isTodoSaving)
            .opacity(viewModel.canSaveTodoDraft ? 1 : 0.45)
        }
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.48))
    }
}

struct NotchTodoDeleteConfirmationView: View {
    @ObservedObject var viewModel: NotchViewModel
    let isMeasuring: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(TodoCopy.deleteTitle)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                NotchBackIconButton(action: viewModel.closeTodoDeleteConfirmation)
            }

            Text(TodoCopy.deleteDetail(viewModel.todoDraftTitle))
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.66))
                .fixedSize(horizontal: false, vertical: true)

            if let message = viewModel.todoErrorMessage, !message.isEmpty {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 1.0, green: 0.58, blue: 0.58))
            }

            HStack {
                Spacer()
                LibraryActionTileButton(
                    icon: .trash,
                    title: viewModel.isTodoDeleting ? TodoCopy.deleting : TodoCopy.confirmDelete,
                    isDestructive: true,
                    action: viewModel.confirmTodoDelete
                )
                .frame(width: LibraryActionTileButton.standardWidth)
                .disabled(viewModel.isTodoDeleting)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct TodoRow: View {
    let todo: TodoItem
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        HStack(spacing: 10) {
            Button(action: { viewModel.toggleTodoCompletion(todo.id) }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(todo.isCompleted ? Color.white : Color.white.opacity(0.04))
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.white.opacity(todo.isCompleted ? 0.9 : 0.22), lineWidth: 1)
                    if todo.isCompleted {
                        NotchPixelIconView(icon: .check, color: .black, size: 9)
                    }
                }
                .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)

            Button(action: { viewModel.openTodoEditor(todo.id) }) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(todo.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(todo.isCompleted ? Color.white.opacity(0.44) : .white)
                            .strikethrough(todo.isCompleted, color: Color.white.opacity(0.36))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        if !todo.detail.isEmpty {
                            Text(todo.detail)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.white.opacity(todo.isCompleted ? 0.34 : 0.62))
                                .lineLimit(1)
                                .multilineTextAlignment(.leading)
                        }

                        if let dueText = viewModel.formattedTodoDueDate(todo) {
                            Text(dueText)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(viewModel.isTodoOverdue(todo) ? TodoPalette.overdue : Color.white.opacity(0.46))
                        }

                        if let source = todo.sourceReferences.first {
                            HStack(spacing: 5) {
                                NotchPixelIconView(icon: .library, color: Color.white.opacity(0.42), size: 9)
                                Text("\(TodoCopy.fromSource) \(source.title)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.white.opacity(0.46))
                                    .lineLimit(1)
                            }
                        }

                        if !todo.sourceReason.isEmpty {
                            Text("\(TodoCopy.why): \(todo.sourceReason)")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.white.opacity(0.42))
                                .lineLimit(2)
                        }
                    }

                    Spacer(minLength: 8)

                    TodoQuadrantPill(quadrant: todo.quadrant)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
        }
    }
}

private struct StaleTodoCard: View {
    let todo: TodoItem
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(todo.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(2)

            Text(TodoCopy.staleForDays(Calendar.current.dateComponents([.day], from: todo.lastProgressAt, to: Date()).day ?? 7))
                .font(.system(size: 10))
                .foregroundStyle(Color.white.opacity(0.46))

            HStack(spacing: 7) {
                TodoCompactAction(title: TodoCopy.delete, destructive: true) { viewModel.deleteStaleTodo(todo.id) }
                TodoCompactAction(title: TodoCopy.deferSevenDays) { viewModel.deferStaleTodo(todo.id) }
                TodoCompactAction(title: TodoCopy.breakDown) { viewModel.breakDownStaleTodo(todo.id) }
            }
            .disabled(viewModel.processingStaleTodoIDs.contains(todo.id))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.045)))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
        }
    }
}

private struct TodoCompactAction: View {
    let title: String
    var destructive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(destructive ? Color(red: 1, green: 0.62, blue: 0.62) : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(destructive ? Color(red: 0.18, green: 0.07, blue: 0.08) : Color.white.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
    }
}

private struct TodoSourcePicker: View {
    @ObservedObject var viewModel: NotchViewModel
    @State private var isPresented = false

    var body: some View {
        Button(action: { isPresented.toggle() }) {
            HStack(spacing: 8) {
                NotchPixelIconView(icon: .library, color: Color.white.opacity(0.72), size: 12)
                Text(viewModel.todoDraftSourceRecordIDs.isEmpty
                    ? TodoCopy.chooseSources
                    : TodoCopy.selectedSourceCount(viewModel.todoDraftSourceRecordIDs.count))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.38))
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(TodoInputBackground())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 5) {
                    ForEach(viewModel.todoSourceCandidates) { record in
                        Button(action: { viewModel.toggleTodoSource(record.id) }) {
                            HStack(spacing: 9) {
                                NotchPixelIconView(
                                    icon: viewModel.todoDraftSourceRecordIDs.contains(record.id) ? .check : .file,
                                    color: Color.white.opacity(0.78),
                                    size: 11
                                )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(record.title)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Text(viewModel.libraryKindLabel(for: record))
                                        .font(.system(size: 9))
                                        .foregroundStyle(Color.white.opacity(0.42))
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 42)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(viewModel.todoDraftSourceRecordIDs.contains(record.id) ? Color.white.opacity(0.10) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
            }
            .frame(width: 320, height: 300)
            .background(Color(red: 0.055, green: 0.055, blue: 0.06))
        }
    }
}

private struct TodoFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.62))
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(isSelected ? Color.white : Color.white.opacity(0.05))
                )
        }
        .buttonStyle(.plain)
    }
}

private struct TodoQuadrantFilterButton: View {
    let title: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isSelected ? Color.black.opacity(0.82) : color)
                .frame(maxWidth: .infinity)
                .frame(height: 27)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? color : color.opacity(0.10))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(color.opacity(isSelected ? 0 : 0.24), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct TodoQuadrantChoice: View {
    let quadrant: TodoQuadrant
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let color = TodoPalette.color(for: quadrant)
        Button(action: action) {
            HStack(spacing: 8) {
                Text(TodoCopy.shortQuadrant(quadrant))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isSelected ? Color.black.opacity(0.82) : color)

                Text(TodoCopy.quadrant(quadrant))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? Color.black.opacity(0.72) : Color.white.opacity(0.68))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? color : color.opacity(0.08))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(color.opacity(isSelected ? 0 : 0.22), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct TodoQuadrantPill: View {
    let quadrant: TodoQuadrant

    var body: some View {
        let color = TodoPalette.color(for: quadrant)
        Text(TodoCopy.shortQuadrant(quadrant))
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .frame(height: 22)
            .background(
                Capsule()
                    .fill(color.opacity(0.10))
            )
            .overlay {
                Capsule()
                    .strokeBorder(color.opacity(0.22), lineWidth: 1)
            }
    }
}

private struct TodoInputBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(0.05))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
            }
    }
}

private struct TodoDateTimePicker: View {
    @Binding var selection: Date

    private var calendar: Calendar { .current }

    private var selectedComponents: DateComponents {
        calendar.dateComponents([.year, .month, .day, .hour, .minute], from: selection)
    }

    private var year: Int { selectedComponents.year ?? calendar.component(.year, from: Date()) }
    private var month: Int { selectedComponents.month ?? 1 }
    private var day: Int { selectedComponents.day ?? 1 }
    private var hour: Int { selectedComponents.hour ?? 0 }
    private var minute: Int { selectedComponents.minute ?? 0 }

    private var availableYears: [Int] {
        let currentYear = calendar.component(.year, from: Date())
        let lowerBound = min(currentYear - 1, year)
        let upperBound = max(currentYear + 10, year)
        return Array(lowerBound ... upperBound)
    }

    private var availableDays: [Int] {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let date = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: date)
        else {
            return Array(1 ... 31)
        }
        return Array(range)
    }

    var body: some View {
        HStack(spacing: 8) {
            picker(
                value: year,
                unit: TodoCopy.yearUnit,
                options: availableYears,
                component: .year
            )

            picker(
                value: month,
                unit: TodoCopy.monthUnit,
                options: Array(1 ... 12),
                component: .month
            )

            picker(
                value: day,
                unit: TodoCopy.dayUnit,
                options: availableDays,
                component: .day
            )

            picker(
                value: hour,
                unit: TodoCopy.hourUnit,
                options: Array(0 ... 23),
                component: .hour,
                padded: true
            )

            picker(
                value: minute,
                unit: TodoCopy.minuteUnit,
                options: Array(0 ... 59),
                component: .minute,
                padded: true
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func picker(
        value: Int,
        unit: String,
        options: [Int],
        component: Calendar.Component,
        padded: Bool = false
    ) -> some View {
        TodoDateTimePickerField(
            value: value,
            unit: unit,
            options: options,
            padded: padded,
            onSelect: { update(component, to: $0) }
        )
    }

    private func optionLabel(_ value: Int, padded: Bool) -> String {
        padded ? String(format: "%02d", value) : String(value)
    }

    private func update(_ component: Calendar.Component, to value: Int) {
        var components = selectedComponents
        components.second = 0

        switch component {
        case .year:
            components.year = value
        case .month:
            components.month = value
        case .day:
            components.day = value
        case .hour:
            components.hour = value
        case .minute:
            components.minute = value
        default:
            return
        }

        components.day = min(components.day ?? 1, maximumDay(for: components))
        if let updatedDate = calendar.date(from: components) {
            selection = updatedDate
        }
    }

    private func maximumDay(for components: DateComponents) -> Int {
        var firstDay = DateComponents()
        firstDay.year = components.year
        firstDay.month = components.month
        firstDay.day = 1

        guard let date = calendar.date(from: firstDay),
              let range = calendar.range(of: .day, in: .month, for: date)
        else {
            return 31
        }
        return range.count
    }
}

private struct TodoDateTimePickerField: View {
    let value: Int
    let unit: String
    let options: [Int]
    let padded: Bool
    let onSelect: (Int) -> Void

    @State private var showsOptions = false

    var body: some View {
        Button(action: { showsOptions.toggle() }) {
            HStack(spacing: 4) {
                Text(optionLabel(value))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Text(unit)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.42))
                    .lineLimit(1)

                Spacer(minLength: 0)

                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.34))
            }
            .padding(.horizontal, 9)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(TodoInputBackground())
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .popover(isPresented: $showsOptions, arrowEdge: .bottom) {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 4) {
                        ForEach(options, id: \.self) { option in
                            Button {
                                onSelect(option)
                                showsOptions = false
                            } label: {
                                HStack(spacing: 8) {
                                    Text("\(optionLabel(option)) \(unit)")
                                        .font(.system(size: 12, weight: option == value ? .semibold : .medium, design: .rounded))
                                        .foregroundStyle(.white)

                                    Spacer(minLength: 0)

                                    if option == value {
                                        NotchPixelIconView(
                                            icon: .check,
                                            color: Color.white.opacity(0.84),
                                            size: 10
                                        )
                                    }
                                }
                                .padding(.horizontal, 10)
                                .frame(height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(option == value ? Color.white.opacity(0.10) : Color.clear)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .id(option)
                        }
                    }
                    .padding(8)
                }
                .frame(width: 116, height: min(220, CGFloat(options.count * 36 + 16)))
                .background(Color(red: 0.055, green: 0.055, blue: 0.06))
                .onAppear {
                    proxy.scrollTo(value, anchor: .center)
                }
            }
        }
    }

    private func optionLabel(_ option: Int) -> String {
        padded ? String(format: "%02d", option) : String(option)
    }
}

private enum TodoPalette {
    static let overdue = Color(red: 1.0, green: 0.48, blue: 0.50)

    static func color(for quadrant: TodoQuadrant) -> Color {
        switch quadrant {
        case .importantUrgent:
            return Color(red: 1.0, green: 0.47, blue: 0.42)
        case .importantNotUrgent:
            return Color(red: 0.42, green: 0.78, blue: 1.0)
        case .urgentNotImportant:
            return Color(red: 1.0, green: 0.76, blue: 0.32)
        case .notImportantNotUrgent:
            return Color(red: 0.66, green: 0.68, blue: 0.72)
        }
    }
}

private enum TodoCopy {
    private static var isChinese: Bool { CasebasePromptCatalog.language == .simplifiedChinese }

    static var title: String { isChinese ? "待办" : "To-do" }
    static var add: String { isChinese ? "新增" : "Add" }
    static var open: String { isChinese ? "未完成" : "Open" }
    static var completed: String { isChinese ? "已完成" : "Completed" }
    static var allQuadrants: String { isChinese ? "全部" : "All" }
    static var loading: String { isChinese ? "正在读取待办…" : "Loading to-dos..." }
    static var retry: String { isChinese ? "重试" : "Retry" }
    static var emptyTitle: String { isChinese ? "先记下下一件要推进的事" : "Capture the next thing to move forward" }
    static var emptyDetail: String { isChinese ? "新增待办时选择四象限，列表会优先呈现重要且紧急的事情。" : "Choose an Eisenhower quadrant when adding a task. Important and urgent work stays first." }
    static var noCompletedTitle: String { isChinese ? "还没有已完成的待办" : "No completed to-dos yet" }
    static var noCompletedDetail: String { isChinese ? "完成的事项会保留在这里，随时可以恢复。" : "Completed items stay here and can be restored anytime." }
    static var needsCleanup: String { isChinese ? "需要整理" : "Needs review" }
    static var needsCleanupDetail: String { isChinese ? "这些事项已经一段时间没有推进，选择删除、延期或重新拆解。" : "These tasks have not moved recently. Delete, defer, or break them down." }
    static var deferSevenDays: String { isChinese ? "延期 7 天" : "Defer 7 days" }
    static var breakDown: String { isChinese ? "重新拆解" : "Break down" }
    static func staleForDays(_ days: Int) -> String { isChinese ? "约 \(max(7, days)) 天没有推进" : "No progress for about \(max(7, days)) days" }
    static var sources: String { isChinese ? "关联资料" : "Sources" }
    static var chooseSources: String { isChinese ? "选择录音、文字稿、图片或文档" : "Choose recordings, transcripts, images, or documents" }
    static func selectedSourceCount(_ count: Int) -> String { isChinese ? "已关联 \(count) 项资料" : "\(count) sources linked" }
    static var sourceReasonPlaceholder: String { isChinese ? "为什么这个待办与这些资料有关？" : "Why is this task linked to these sources?" }
    static var fromSource: String { isChinese ? "来自" : "From" }
    static var why: String { isChinese ? "原因" : "Why" }
    static var newTitle: String { isChinese ? "新增待办" : "New to-do" }
    static var editTitle: String { isChinese ? "编辑待办" : "Edit to-do" }
    static var todoTitle: String { isChinese ? "标题" : "Title" }
    static var titlePlaceholder: String { isChinese ? "要完成什么？" : "What needs to be done?" }
    static var detail: String { isChinese ? "简单描述" : "Description" }
    static var quadrant: String { isChinese ? "四象限" : "Quadrant" }
    static var dueDate: String { isChinese ? "截止时间" : "Due date" }
    static var yearUnit: String { isChinese ? "年" : "Y" }
    static var monthUnit: String { isChinese ? "月" : "M" }
    static var dayUnit: String { isChinese ? "日" : "D" }
    static var hourUnit: String { isChinese ? "时" : "H" }
    static var minuteUnit: String { isChinese ? "分" : "Min" }
    static var save: String { isChinese ? "保存" : "Save" }
    static var saving: String { isChinese ? "保存中…" : "Saving..." }
    static var delete: String { isChinese ? "删除" : "Delete" }
    static var deleteTitle: String { isChinese ? "删除这个待办？" : "Delete this to-do?" }
    static var confirmDelete: String { isChinese ? "确认删除" : "Delete" }
    static var deleting: String { isChinese ? "删除中…" : "Deleting..." }

    static func shortQuadrant(_ quadrant: TodoQuadrant) -> String {
        switch quadrant {
        case .importantUrgent: return "Q1"
        case .importantNotUrgent: return "Q2"
        case .urgentNotImportant: return "Q3"
        case .notImportantNotUrgent: return "Q4"
        }
    }

    static func quadrant(_ quadrant: TodoQuadrant) -> String {
        switch quadrant {
        case .importantUrgent:
            return isChinese ? "重要且紧急" : "Important & urgent"
        case .importantNotUrgent:
            return isChinese ? "重要不紧急" : "Important, not urgent"
        case .urgentNotImportant:
            return isChinese ? "紧急不重要" : "Urgent, not important"
        case .notImportantNotUrgent:
            return isChinese ? "不重要不紧急" : "Neither important nor urgent"
        }
    }

    static func deleteDetail(_ title: String) -> String {
        if isChinese {
            return "“\(title)”会从待办列表中永久删除，此操作无法撤销。"
        }
        return "\"\(title)\" will be permanently removed from your to-do list. This cannot be undone."
    }
}
