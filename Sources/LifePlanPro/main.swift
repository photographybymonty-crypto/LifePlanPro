import SwiftUI
import AppKit

struct PlannerTask: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var category: String
    var dueHour: Int
    var completed = false
    var priority = false
}

struct CalendarEvent: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var startHour: Int
    var category: String
}

struct ProjectCard: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var progress: Double
    var tag: String
}

struct GoalCard: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var progress: Double
}

struct PlannerNote: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var dateText: String
}

struct StoredData: Codable {
    var tasks: [PlannerTask]
    var events: [CalendarEvent]
    var projects: [ProjectCard]
    var goals: [GoalCard]
    var notes: [PlannerNote]
}

@MainActor final class PlannerStore: ObservableObject {
    @Published var selected = "Today"
    @Published var search = ""
    @Published var showAddTask = false
    @Published var showAddEvent = false
    @Published var aiMessage = ""
    @Published var lightMode = UserDefaults.standard.bool(forKey: "LifePlanLightMode") {
        didSet { UserDefaults.standard.set(lightMode, forKey: "LifePlanLightMode") }
    }
    @Published var tasks: [PlannerTask] = [] { didSet { save() } }
    @Published var events: [CalendarEvent] = [] { didSet { save() } }
    @Published var projects: [ProjectCard] = [] { didSet { save() } }
    @Published var goals: [GoalCard] = [] { didSet { save() } }
    @Published var notes: [PlannerNote] = [] { didSet { save() } }

    private var loading = true

    init() {
        load()
        loading = false
    }

    private var url: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = base.appendingPathComponent("LifePlanPro", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("planner.json")
    }

    func load() {
        if let data = try? Data(contentsOf: url),
           let stored = try? JSONDecoder().decode(StoredData.self, from: data) {
            tasks = stored.tasks
            events = stored.events
            projects = stored.projects
            goals = stored.goals
            notes = stored.notes
        } else {
            samples()
        }
    }

    func save() {
        guard !loading else { return }
        let stored = StoredData(tasks: tasks, events: events, projects: projects, goals: goals, notes: notes)
        if let data = try? JSONEncoder().encode(stored) {
            try? data.write(to: url, options: .atomic)
        }
    }

    func samples() {
        tasks = [
            .init(title: "Edit video for client", category: "Work", dueHour: 10, priority: true),
            .init(title: "Send invoice to Johnson", category: "Work", dueHour: 12, priority: true),
            .init(title: "Pick up kids from school", category: "Family", dueHour: 16),
            .init(title: "Call Mike about shoot", category: "Work", dueHour: 9, completed: true),
            .init(title: "Order equipment", category: "Work", dueHour: 17),
            .init(title: "Plan next week", category: "Personal", dueHour: 20)
        ]
        events = [
            .init(title: "Lawn Job – 2075 Jessica Way", startHour: 9, category: "Business"),
            .init(title: "Client Call – Motive Films", startHour: 11, category: "Work"),
            .init(title: "Production Meeting", startHour: 14, category: "Work"),
            .init(title: "Pick Up Kids", startHour: 16, category: "Family"),
            .init(title: "Family Movie Night", startHour: 19, category: "Family")
        ]
        projects = [
            .init(title: "Motive Films", progress: 0.30, tag: "Production"),
            .init(title: "Motive Green Homes", progress: 0.42, tag: "Business"),
            .init(title: "Homeschool 2026–2027", progress: 0.40, tag: "Education")
        ]
        goals = [
            .init(title: "Grow My Businesses", progress: 0.70),
            .init(title: "Pay Off Debt", progress: 0.45),
            .init(title: "Take Family on Vacation", progress: 0.30),
            .init(title: "Be a Better Father", progress: 0.80),
            .init(title: "Financial Freedom", progress: 0.25)
        ]
        notes = [
            .init(title: "Ideas for new YouTube series", dateText: "Today at 8:12 AM"),
            .init(title: "Homeschool curriculum options", dateText: "Yesterday at 6:45 PM"),
            .init(title: "Equipment to purchase", dateText: "Sep 10, 2026"),
            .init(title: "Family vacation ideas", dateText: "Sep 9, 2026")
        ]
    }

    func plan() {
        let priority = tasks.filter { !$0.completed && $0.priority }
        aiMessage = priority.isEmpty
            ? "Your day is balanced. Start with the earliest unfinished task and keep a 30-minute buffer."
            : "Start with \(priority[0].title), then move to the next priority before lower-impact work."
    }
}

let appBackground = Color(nsColor: .windowBackgroundColor)
let cardBackground = Color(nsColor: .controlBackgroundColor)
let separator = Color(nsColor: .separatorColor)
let accent = Color(nsColor: NSColor(name: nil) { appearance in
    let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    return dark
        ? NSColor(calibratedRed: 0.39, green: 0.24, blue: 0.95, alpha: 1)
        : NSColor(calibratedRed: 0.00, green: 0.69, blue: 0.72, alpha: 1)
})
let blue = Color(red: 0.12, green: 0.45, blue: 1.0)
let green = Color(red: 0.08, green: 0.78, blue: 0.38)
let pink = Color(red: 1.0, green: 0.20, blue: 0.50)
let orange = Color(red: 1.0, green: 0.42, blue: 0.08)
let tiffany = Color(red: 0.00, green: 0.69, blue: 0.72)

func hourText(_ hour: Int) -> String {
    let period = hour < 12 ? "AM" : "PM"
    let display = hour % 12 == 0 ? 12 : hour % 12
    return "\(display):00 \(period)"
}

func categoryColor(_ category: String) -> Color {
    switch category {
    case "Family": return pink
    case "Business": return green
    case "School": return .teal
    case "Personal": return orange
    default: return accent
    }
}

struct Card<Content: View>: View {
    let content: Content
    init(@ViewBuilder _ content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(14)
            .background(cardBackground.opacity(0.97))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(separator.opacity(0.7)))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct MountainScene: View {
    @State private var now = Date()
    var hour: Int { Calendar.current.component(.hour, from: now) }
    var sky: [Color] {
        switch hour {
        case 5..<10: return [Color.cyan.opacity(0.55), Color.orange.opacity(0.65), Color.yellow.opacity(0.35)]
        case 10..<17: return [Color.cyan.opacity(0.65), Color.blue.opacity(0.45), Color.indigo.opacity(0.28)]
        case 17..<20: return [Color.indigo.opacity(0.75), Color.pink.opacity(0.58), Color.orange.opacity(0.70)]
        default: return [Color.black, Color.indigo.opacity(0.70), Color.blue.opacity(0.30)]
        }
    }
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            ZStack {
                LinearGradient(colors: sky, startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle()
                    .fill(hour >= 20 || hour < 5 ? Color.white.opacity(0.8) : Color.orange.opacity(0.9))
                    .frame(width: 72, height: 72)
                    .blur(radius: 2)
                    .offset(x: 280, y: -28)
                MountainShape(seed: 0).fill(Color.black.opacity(0.30)).offset(y: 48)
                MountainShape(seed: 1).fill(Color(red: 0.04, green: 0.18, blue: 0.18).opacity(0.65)).offset(y: 73)
                LinearGradient(colors: [Color.clear, Color.black.opacity(0.28)], startPoint: .top, endPoint: .bottom)
            }
            .onChange(of: context.date) { value in now = value }
        }
    }
}

struct MountainShape: Shape {
    let seed: Int
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height))
        let points = seed == 0 ? [0.0, 0.12, 0.25, 0.37, 0.52, 0.68, 0.82, 1.0] : [0.0, 0.18, 0.34, 0.49, 0.63, 0.78, 1.0]
        let heights = seed == 0 ? [0.72, 0.42, 0.62, 0.29, 0.61, 0.35, 0.63, 0.49] : [0.80, 0.58, 0.73, 0.47, 0.69, 0.54, 0.75]
        for (index, x) in points.enumerated() {
            path.addLine(to: CGPoint(x: rect.width * x, y: rect.height * heights[index]))
        }
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

@main struct LifePlanProApp: App {
    @StateObject private var store = PlannerStore()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(store.lightMode ? .light : .dark)
                .frame(minWidth: 1260, minHeight: 820)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
    }
}

struct RootView: View {
    @EnvironmentObject var store: PlannerStore
    var body: some View {
        HStack(spacing: 0) {
            Sidebar().frame(width: 230)
            Divider()
            VStack(spacing: 0) {
                TopBar()
                content
            }
        }
        .background(appBackground)
        .sheet(isPresented: $store.showAddTask) { AddTaskSheet() }
        .sheet(isPresented: $store.showAddEvent) { AddEventSheet() }
    }

    @ViewBuilder var content: some View {
        switch store.selected {
        case "Today": Dashboard()
        case "Calendar": CalendarPage()
        case "Tasks": TasksPage()
        case "Projects": ProjectsPage()
        case "Goals": GoalsPage()
        case "Money": MoneyPage()
        case "Family": FamilyPage()
        case "School": SchoolPage()
        case "Notes": NotesPage()
        case "Files": FilesPage()
        case "Contacts": ContactsPage()
        case "Planner Maker": PlannerMakerPage()
        case "Templates": TemplatesPage()
        case "AI Planner": AIPlannerPage()
        case "Habit Tracker": HabitTrackerPage()
        case "Meal Planner": MealPlannerPage()
        case "Travel": TravelPage()
        case "Reports": ReportsPage()
        case "Settings": SettingsPage()
        default: Dashboard()
        }
    }
}

struct Sidebar: View {
    @EnvironmentObject var store: PlannerStore
    let main = [
        ("Today", "house.fill"), ("Calendar", "calendar"), ("Tasks", "checkmark.square"),
        ("Projects", "folder"), ("Goals", "scope"), ("Money", "dollarsign.circle"),
        ("Family", "person.3"), ("School", "graduationcap"), ("Notes", "doc.text"),
        ("Files", "folder.fill"), ("Contacts", "person.crop.square"),
        ("Planner Maker", "rectangle.3.group"), ("Templates", "square.grid.2x2")
    ]
    let tools = [
        ("AI Planner", "sparkles"), ("Habit Tracker", "heart"), ("Meal Planner", "fork.knife"),
        ("Travel", "airplane"), ("Reports", "chart.bar"), ("Settings", "gearshape")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(colors: [tiffany, accent], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 38, height: 38)
                    .overlay(Image(systemName: "diamond.fill").rotationEffect(.degrees(45)).foregroundStyle(.white))
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 3) {
                        Text("LifePlan").font(.system(size: 20, weight: .bold))
                        Text("Pro").font(.system(size: 14, weight: .semibold)).foregroundStyle(accent)
                    }
                    Text("Plan Today. Build Tomorrow.").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 18)
            .padding(.bottom, 8)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 3) {
                    ForEach(main, id: \.0) { item in nav(item.0, item.1) }
                    Divider().padding(.horizontal, 14).padding(.vertical, 7)
                    Text("Tools")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                    ForEach(tools, id: \.0) { item in nav(item.0, item.1) }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Label("A More Organized You", systemImage: "leaf.fill").font(.caption).bold()
                Text("A Brighter Tomorrow.").font(.caption).foregroundStyle(accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(13)
            .background(accent.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(12)
        }
        .background(cardBackground.opacity(0.45))
    }

    func nav(_ title: String, _ icon: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) { store.selected = title }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon).frame(width: 22)
                Text(title)
                Spacer()
                if title == "Tasks" { badge("\(store.tasks.filter { !$0.completed }.count)") }
                if title == "Projects" { badge("\(store.projects.count)") }
                if title == "Family" { badge("2") }
                if title == "School" { badge("1") }
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 12)
            .foregroundStyle(store.selected == title ? Color.white : Color.primary)
            .background(store.selected == title ? accent : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }

    func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(store.selected == "Tasks" ? Color.white.opacity(0.22) : accent.opacity(0.15))
            .clipShape(Capsule())
    }
}

struct TopBar: View {
    @EnvironmentObject var store: PlannerStore
    var body: some View {
        HStack(spacing: 14) {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search anything… (tasks, events, notes, files, people…)", text: $store.search)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 14)
            .frame(width: 520, height: 34)
            .background(cardBackground)
            .overlay(Capsule().stroke(separator.opacity(0.8)))
            .clipShape(Capsule())
            Spacer()
            Image(systemName: "bell")
            Button {
                store.lightMode.toggle()
            } label: {
                Label(store.lightMode ? "Light" : "Dark", systemImage: store.lightMode ? "sun.max.fill" : "moon.stars.fill")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(accent.opacity(0.13))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            Circle().fill(accent).frame(width: 30, height: 30).overlay(Text("M").bold().foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 0) {
                Text("Good Morning,").font(.caption2).foregroundStyle(.secondary)
                Text("Monty").font(.caption).bold()
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 58)
        .background(cardBackground.opacity(0.72))
    }
}

struct Dashboard: View {
    @EnvironmentObject var store: PlannerStore
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HeroHeader()
                SummaryStrip()
                HStack(alignment: .top, spacing: 12) {
                    CalendarCard().frame(maxWidth: .infinity)
                    TasksCard().frame(maxWidth: .infinity)
                    UpcomingCard().frame(maxWidth: .infinity)
                    VStack(spacing: 12) {
                        AIPlannerCard()
                        GoalsCard()
                    }.frame(width: 245)
                }
                HStack(alignment: .top, spacing: 12) {
                    ProjectsCard().frame(maxWidth: .infinity)
                    NotesCard().frame(width: 320)
                }
                AIBar()
            }
            .padding(14)
        }
        .background(appBackground)
    }
}

struct HeroHeader: View {
    var body: some View {
        ZStack(alignment: .leading) {
            MountainScene()
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Good Morning, Monty").font(.system(size: 32, weight: .bold)).foregroundStyle(.white)
                    Text("Stay consistent. Great things take planned action.").font(.title3).foregroundStyle(.white.opacity(0.92))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 12) {
                    Text(Date.now.formatted(date: .complete, time: .omitted)).font(.subheadline.bold()).foregroundStyle(.white)
                    Text("“A well planned day\ncreates a better tomorrow.”")
                        .italic().multilineTextAlignment(.trailing).foregroundStyle(.white)
                }
            }
            .padding(24)
        }
        .frame(height: 165)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct SummaryStrip: View {
    @EnvironmentObject var store: PlannerStore
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                SummaryTile(icon: "calendar", value: "\(store.events.count)", title: "Today's Events", color: blue)
                SummaryTile(icon: "checkmark", value: "\(store.tasks.filter { !$0.completed }.count)", title: "Tasks Due", color: green)
                SummaryTile(icon: "folder", value: "\(store.projects.count)", title: "Active Projects", color: accent)
                SummaryTile(icon: "scope", value: "2", title: "Goals This Week", color: orange)
                SummaryTile(icon: "person.2.fill", value: "Family", title: "2 upcoming", color: pink)
                SummaryTile(icon: "graduationcap.fill", value: "School", title: "1 assignment", color: .teal)
                SummaryTile(icon: "dollarsign", value: "1", title: "Bill Due", color: green)
            }
        }
    }
}

struct SummaryTile: View {
    let icon: String
    let value: String
    let title: String
    let color: Color
    var body: some View {
        Card {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 9)
                    .fill(color.opacity(0.17))
                    .frame(width: 38, height: 38)
                    .overlay(Image(systemName: icon).foregroundStyle(color))
                VStack(alignment: .leading, spacing: 2) {
                    Text(value).font(.headline).bold().lineLimit(1)
                    Text(title).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(width: 145, height: 74)
    }
}

struct SectionHeader: View {
    let icon: String
    let title: String
    let trailing: String
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundStyle(accent)
            Text(title).font(.headline)
            Spacer()
            Text(trailing).font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct CalendarCard: View {
    @EnvironmentObject var store: PlannerStore
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(icon: "calendar", title: "Calendar", trailing: "Week")
                HStack {
                    Text("September 2026").bold()
                    Spacer()
                    Image(systemName: "chevron.left")
                    Text("Today").font(.caption).padding(5).background(accent.opacity(0.10)).clipShape(Capsule())
                    Image(systemName: "chevron.right")
                }
                HStack {
                    ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                        Text(day).font(.caption2).frame(maxWidth: .infinity)
                    }
                }
                HStack {
                    ForEach(["6", "7", "8", "9", "10", "11", "12"], id: \.self) { day in
                        Text(day).font(.caption).frame(maxWidth: .infinity).padding(5)
                            .background(day == "12" ? accent : Color.clear)
                            .foregroundStyle(day == "12" ? Color.white : Color.primary)
                            .clipShape(Circle())
                    }
                }
                Divider()
                ForEach(store.events.prefix(5)) { event in
                    HStack {
                        Text(hourText(event.startHour)).font(.caption2).frame(width: 58, alignment: .leading).foregroundStyle(.secondary)
                        RoundedRectangle(cornerRadius: 4).fill(categoryColor(event.category)).frame(width: 7, height: 27)
                        Text(event.title).font(.caption).lineLimit(1)
                        Spacer()
                    }.padding(.vertical, 2)
                }
                Button("+ Add Event") { store.showAddEvent = true }.buttonStyle(.plain).foregroundStyle(accent)
            }
        }
    }
}

struct TasksCard: View {
    @EnvironmentObject var store: PlannerStore
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 9) {
                SectionHeader(icon: "checkmark.square", title: "Tasks", trailing: "Today")
                HStack {
                    Text("All (\(store.tasks.count))").chip(accent)
                    Text("High (\(store.tasks.filter { $0.priority && !$0.completed }.count))").chip(Color.red)
                    Spacer()
                    Button { store.showAddTask = true } label: { Image(systemName: "plus") }.buttonStyle(.bordered)
                }
                ForEach(store.tasks.prefix(6)) { task in
                    HStack {
                        Button {
                            if let index = store.tasks.firstIndex(where: { $0.id == task.id }) { store.tasks[index].completed.toggle() }
                        } label: {
                            Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(task.completed ? green : Color.secondary)
                        }.buttonStyle(.plain)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(task.title).font(.caption).strikethrough(task.completed)
                            Text(task.category).font(.caption2).foregroundStyle(categoryColor(task.category))
                        }
                        Spacer()
                        Text(hourText(task.dueHour)).font(.caption2).foregroundStyle(.secondary)
                    }.padding(.vertical, 3)
                }
            }
        }
    }
}

extension Text {
    func chip(_ color: Color) -> some View {
        self.font(.caption).padding(.horizontal, 8).padding(.vertical, 5)
            .background(color.opacity(0.14)).foregroundStyle(color).clipShape(Capsule())
    }
}

struct UpcomingCard: View {
    let rows = [
        ("Sun\nSep 13", "Church Service", "10:00 AM", Color.red),
        ("Mon\nSep 14", "Homeschool – Science", "9:00 AM", blue),
        ("Tue\nSep 15", "Lawn Job – Snellville", "8:00 AM", green),
        ("Wed\nSep 16", "Doctor Appointment", "11:00 AM", orange),
        ("Thu\nSep 17", "Film Shoot Prep", "2:00 PM", tiffany),
        ("Fri\nSep 18", "Kids Field Trip", "9:00 AM", blue),
        ("Sat\nSep 19", "Family Day", "All Day", pink)
    ]
    var body: some View {
        Card {
            VStack(spacing: 0) {
                SectionHeader(icon: "calendar.badge.clock", title: "Upcoming", trailing: "Next 7 Days")
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack {
                        Text(row.0).font(.caption2).frame(width: 44, alignment: .leading)
                        Circle().fill(row.3).frame(width: 7, height: 7)
                        Text(row.1).font(.caption).lineLimit(1)
                        Spacer()
                        Text(row.2).font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 7)
                    Divider()
                }
            }
        }
    }
}

struct AIPlannerCard: View {
    @EnvironmentObject var store: PlannerStore
    let prompts = ["Plan my day", "Break down a project", "Create a schedule", "Generate a meal plan", "Organize my finances", "Plan a homeschool month", "Find time for this…"]
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "sparkles").foregroundStyle(accent)
                    Text("AI Planner").bold()
                    Spacer()
                    Text("Pro").font(.caption2.bold()).padding(4).background(accent).foregroundStyle(.white).clipShape(Capsule())
                }
                Text("How can I help you today?").font(.caption).foregroundStyle(.secondary)
                ForEach(prompts, id: \.self) { prompt in
                    Button(prompt) {
                        store.aiMessage = prompt == "Plan my day" ? "I'll prioritize urgent work, protect family time, and keep realistic buffers." : "I can help with \(prompt.lowercased())."
                    }
                    .buttonStyle(.plain).font(.caption).padding(6).frame(maxWidth: .infinity, alignment: .leading)
                    .background(accent.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 7))
                }
            }
        }
    }
}

struct GoalsCard: View {
    @EnvironmentObject var store: PlannerStore
    var body: some View {
        Card {
            VStack(spacing: 8) {
                SectionHeader(icon: "scope", title: "Life Goals", trailing: "View All")
                ForEach(store.goals.prefix(4)) { goal in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(goal.title).font(.caption)
                            Spacer()
                            Text("\(Int(goal.progress * 100))%").font(.caption2).foregroundStyle(.secondary)
                        }
                        ProgressView(value: goal.progress).tint(goal.progress > 0.65 ? green : accent)
                    }
                }
            }
        }
    }
}

struct ProjectsCard: View {
    @EnvironmentObject var store: PlannerStore
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(icon: "folder", title: "Projects", trailing: "View All")
                HStack(spacing: 10) {
                    ForEach(store.projects) { project in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(project.title).bold().font(.caption)
                            Text(project.tag).font(.caption2).foregroundStyle(.secondary)
                            ProgressView(value: project.progress).tint(accent)
                            Text("\(Int(project.progress * 100))% complete").font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(accent.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }
}

struct NotesCard: View {
    @EnvironmentObject var store: PlannerStore
    var body: some View {
        Card {
            VStack(spacing: 0) {
                SectionHeader(icon: "note.text", title: "Notes", trailing: "View All")
                ForEach(store.notes) { note in
                    HStack {
                        Image(systemName: "note.text").foregroundStyle(.yellow)
                        VStack(alignment: .leading) {
                            Text(note.title).font(.caption)
                            Text(note.dateText).font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }.padding(.vertical, 7)
                    Divider()
                }
            }
        }
    }
}

struct AIBar: View {
    @EnvironmentObject var store: PlannerStore
    @State private var text = ""
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles").foregroundStyle(accent)
            TextField("Tell AI what you want to do…", text: $text).textFieldStyle(.plain)
            Button("Plan My Day") { store.plan() }.buttonStyle(.bordered)
            Button("Go") {
                store.aiMessage = text.isEmpty ? "Tell me what you want to organize." : "I turned “\(text)” into a next action."
                text = ""
            }.buttonStyle(.borderedProminent).tint(accent)
        }
        .padding(12)
        .background(cardBackground)
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(accent.opacity(0.22)))
        .clipShape(RoundedRectangle(cornerRadius: 13))
    }
}

struct PageShell<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content
    init(_ title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.largeTitle).bold()
                    Text(subtitle).foregroundStyle(.secondary)
                }
                content
            }
            .padding(26)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(appBackground)
    }
}

struct CalendarPage: View {
    var body: some View { PageShell("Calendar", subtitle: "Your complete schedule in one place.") { CalendarCard().frame(maxWidth: 760); UpcomingCard().frame(maxWidth: 760) } }
}

struct TasksPage: View {
    @EnvironmentObject var store: PlannerStore
    var body: some View {
        PageShell("Tasks", subtitle: "Capture, prioritize, and complete what matters.") {
            HStack { Spacer(); Button("Add Task") { store.showAddTask = true }.buttonStyle(.borderedProminent).tint(accent) }
            Card {
                VStack(spacing: 0) {
                    ForEach(store.tasks) { task in
                        HStack {
                            Button {
                                if let i = store.tasks.firstIndex(where: { $0.id == task.id }) { store.tasks[i].completed.toggle() }
                            } label: { Image(systemName: task.completed ? "checkmark.circle.fill" : "circle").foregroundStyle(task.completed ? green : Color.secondary) }
                            .buttonStyle(.plain)
                            VStack(alignment: .leading) { Text(task.title); Text(task.category).font(.caption).foregroundStyle(categoryColor(task.category)) }
                            Spacer(); Text(hourText(task.dueHour)).foregroundStyle(.secondary)
                        }.padding(.vertical, 10)
                        Divider()
                    }
                }
            }.frame(maxWidth: 760)
        }
    }
}

struct ProjectsPage: View {
    @EnvironmentObject var store: PlannerStore
    var body: some View {
        PageShell("Projects", subtitle: "Plan work from idea to completion.") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 14)], spacing: 14) {
                ForEach(store.projects) { project in
                    Card { VStack(alignment: .leading, spacing: 10) { Text(project.title).font(.title3).bold(); Text(project.tag).foregroundStyle(.secondary); ProgressView(value: project.progress).tint(accent); Text("\(Int(project.progress * 100))% complete").font(.caption) } }
                }
            }
        }
    }
}

struct GoalsPage: View { var body: some View { PageShell("Goals", subtitle: "Turn long-term goals into visible progress.") { GoalsCard().frame(maxWidth: 700) } } }
struct NotesPage: View { var body: some View { PageShell("Notes", subtitle: "Keep ideas, lists, and reference notes together.") { NotesCard().frame(maxWidth: 760) } } }

struct MoneyPage: View {
    var body: some View { PageShell("Money", subtitle: "Track bills, budgets, and financial goals.") { ModuleGrid(items: [("Bills Due", "$327", "creditcard"), ("Monthly Budget", "$4,800", "chart.pie"), ("Savings Goal", "45%", "banknote"), ("Subscriptions", "6", "repeat")]) } }
}

struct FamilyPage: View {
    var body: some View { PageShell("Family", subtitle: "Shared plans, chores, events, and family routines.") { ModuleGrid(items: [("Upcoming", "2", "calendar"), ("Chores", "8", "checklist"), ("Allowances", "$24", "dollarsign.circle"), ("Family Night", "Friday", "film")]) } }
}

struct SchoolPage: View {
    var body: some View { PageShell("School", subtitle: "Homeschool lessons, assignments, attendance, and field trips.") { ModuleGrid(items: [("Assignments", "1 due", "book"), ("Attendance", "100%", "checkmark.seal"), ("Field Trips", "3", "bus"), ("Subjects", "6", "books.vertical")]) } }
}

struct FilesPage: View {
    var body: some View { PageShell("Files", subtitle: "Attach important documents to your plans and projects.") { ModuleGrid(items: [("Recent Files", "12", "doc"), ("Project Files", "18", "folder"), ("School Files", "9", "graduationcap"), ("Shared", "4", "person.2")]) } }
}

struct ContactsPage: View {
    var body: some View { PageShell("Contacts", subtitle: "People connected to your work, family, and projects.") { ModuleGrid(items: [("Clients", "14", "person.crop.circle"), ("Family", "6", "person.3"), ("Crew", "9", "camera"), ("Vendors", "11", "building.2")]) } }
}

struct PlannerMakerPage: View {
    var body: some View { PageShell("Planner Maker", subtitle: "Create printable and digital planner pages.") { ModuleGrid(items: [("Daily Planner", "Create", "sun.max"), ("Weekly Planner", "Create", "calendar.badge.clock"), ("Chore Chart", "Create", "checklist"), ("Habit Sheet", "Create", "heart")]) } }
}

struct TemplatesPage: View {
    var body: some View { PageShell("Templates", subtitle: "Start quickly with layouts for life, family, school, and work.") { ModuleGrid(items: [("Family Planner", "Popular", "person.3"), ("Business Week", "New", "briefcase"), ("Homeschool Month", "Popular", "graduationcap"), ("Budget Planner", "New", "dollarsign.circle")]) } }
}

struct AIPlannerPage: View {
    @EnvironmentObject var store: PlannerStore
    var body: some View { PageShell("AI Planner", subtitle: "Describe what you need and let LifePlan organize it.") { AIPlannerCard().frame(maxWidth: 520); if !store.aiMessage.isEmpty { Card { Text(store.aiMessage) }.frame(maxWidth: 700) } } }
}

struct HabitTrackerPage: View {
    var body: some View { PageShell("Habit Tracker", subtitle: "Build routines with simple daily streaks.") { ModuleGrid(items: [("Drink Water", "6 day streak", "drop"), ("Exercise", "4 day streak", "figure.walk"), ("Read", "12 day streak", "book"), ("Plan Tomorrow", "8 day streak", "calendar")]) } }
}

struct MealPlannerPage: View {
    var body: some View { PageShell("Meal Planner", subtitle: "Plan meals and keep grocery needs organized.") { ModuleGrid(items: [("Breakfast", "Oatmeal", "sunrise"), ("Lunch", "Chicken Salad", "fork.knife"), ("Dinner", "Tacos", "takeoutbag.and.cup.and.straw"), ("Groceries", "14 items", "cart")]) } }
}

struct TravelPage: View {
    var body: some View { PageShell("Travel", subtitle: "Trips, itineraries, reservations, and packing lists.") { ModuleGrid(items: [("Next Trip", "Family Vacation", "airplane"), ("Reservations", "3", "ticket"), ("Packing", "18 items", "suitcase"), ("Budget", "$1,200", "dollarsign.circle")]) } }
}

struct ReportsPage: View {
    var body: some View { PageShell("Reports", subtitle: "See progress across your plans at a glance.") { ModuleGrid(items: [("Task Completion", "78%", "chart.bar"), ("Goal Progress", "50%", "scope"), ("Project Health", "Good", "heart.text.square"), ("Weekly Focus", "Work", "sparkles")]) } }
}

struct SettingsPage: View {
    @EnvironmentObject var store: PlannerStore
    var body: some View {
        PageShell("Settings", subtitle: "Personalize your LifePlan Pro experience.") {
            Card {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle("Tiffany Light Mode", isOn: $store.lightMode)
                    Divider()
                    HStack { Text("Theme Accent"); Spacer(); Circle().fill(store.lightMode ? tiffany : accent).frame(width: 24, height: 24) }
                    HStack { Text("Data Storage"); Spacer(); Text("On this Mac").foregroundStyle(.secondary) }
                }
            }.frame(maxWidth: 620)
        }
    }
}

struct ModuleGrid: View {
    let items: [(String, String, String)]
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Card {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 10).fill(accent.opacity(0.12)).frame(width: 46, height: 46)
                            .overlay(Image(systemName: item.2).foregroundStyle(accent).font(.title3))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.0).font(.headline)
                            Text(item.1).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
}

struct AddTaskSheet: View {
    @EnvironmentObject var store: PlannerStore
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var category = "Personal"
    @State private var hour = 9
    @State private var priority = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Task").font(.title2).bold()
            TextField("Task title", text: $title)
            Picker("Category", selection: $category) { ForEach(["Personal", "Work", "Family", "School"], id: \.self) { Text($0) } }
            Stepper("Due: \(hourText(hour))", value: $hour, in: 0...23)
            Toggle("High priority", isOn: $priority)
            HStack { Spacer(); Button("Cancel") { dismiss() }; Button("Add") { add() }.buttonStyle(.borderedProminent).tint(accent) }
        }.padding(24).frame(width: 420)
    }
    func add() {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        store.tasks.append(.init(title: cleaned, category: category, dueHour: hour, priority: priority))
        dismiss()
    }
}

struct AddEventSheet: View {
    @EnvironmentObject var store: PlannerStore
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var hour = 9
    @State private var category = "Work"
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Event").font(.title2).bold()
            TextField("Event title", text: $title)
            Picker("Category", selection: $category) { ForEach(["Work", "Business", "Family", "School"], id: \.self) { Text($0) } }
            Stepper("Start: \(hourText(hour))", value: $hour, in: 0...23)
            HStack { Spacer(); Button("Cancel") { dismiss() }; Button("Add") { add() }.buttonStyle(.borderedProminent).tint(accent) }
        }.padding(24).frame(width: 420)
    }
    func add() {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        store.events.append(.init(title: cleaned, startHour: hour, category: category))
        dismiss()
    }
}
