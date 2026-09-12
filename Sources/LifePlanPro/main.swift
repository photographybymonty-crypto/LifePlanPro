import SwiftUI
import AppKit

struct PlannerTask: Identifiable, Codable, Hashable {
    var id = UUID(); var title: String; var category: String; var dueHour: Int; var completed = false; var priority = false
}
struct CalendarEvent: Identifiable, Codable, Hashable {
    var id = UUID(); var title: String; var startHour: Int; var category: String
}
struct ProjectCard: Identifiable, Codable, Hashable { var id = UUID(); var title: String; var progress: Double; var tag: String }
struct GoalCard: Identifiable, Codable, Hashable { var id = UUID(); var title: String; var progress: Double }
struct PlannerNote: Identifiable, Codable, Hashable { var id = UUID(); var title: String; var dateText: String }
struct StoredData: Codable { var tasks:[PlannerTask]; var events:[CalendarEvent]; var projects:[ProjectCard]; var goals:[GoalCard]; var notes:[PlannerNote] }

@MainActor final class PlannerStore: ObservableObject {
    @Published var selected = "Today"
    @Published var search = ""
    @Published var showAddTask = false
    @Published var showAddEvent = false
    @Published var aiMessage = ""
    @Published var tasks:[PlannerTask] = [] { didSet { save() } }
    @Published var events:[CalendarEvent] = [] { didSet { save() } }
    @Published var projects:[ProjectCard] = [] { didSet { save() } }
    @Published var goals:[GoalCard] = [] { didSet { save() } }
    @Published var notes:[PlannerNote] = [] { didSet { save() } }
    private var loading = true
    init(){ load(); loading = false }
    private var url: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = base.appendingPathComponent("LifePlanPro", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("planner.json")
    }
    func load(){
        if let d = try? Data(contentsOf: url), let s = try? JSONDecoder().decode(StoredData.self, from: d) {
            tasks=s.tasks; events=s.events; projects=s.projects; goals=s.goals; notes=s.notes
        } else { samples() }
    }
    func save(){ guard !loading else { return }; let s=StoredData(tasks:tasks,events:events,projects:projects,goals:goals,notes:notes); if let d=try? JSONEncoder().encode(s){ try? d.write(to:url,options:.atomic) } }
    func samples(){
        tasks=[
            .init(title:"Edit video for client",category:"Work",dueHour:10,priority:true),
            .init(title:"Send invoice to Johnson",category:"Work",dueHour:12,priority:true),
            .init(title:"Pick up kids from school",category:"Family",dueHour:16),
            .init(title:"Call Mike about shoot",category:"Work",dueHour:9,completed:true),
            .init(title:"Order equipment",category:"Work",dueHour:17),
            .init(title:"Plan next week",category:"Personal",dueHour:20)
        ]
        events=[
            .init(title:"Lawn Job – 2075 Jessica Way",startHour:9,category:"Business"),
            .init(title:"Client Call – Motive Films",startHour:11,category:"Work"),
            .init(title:"Production Meeting",startHour:14,category:"Work"),
            .init(title:"Pick Up Kids",startHour:16,category:"Family"),
            .init(title:"Family Movie Night",startHour:19,category:"Family")
        ]
        projects=[.init(title:"Motive Films",progress:0.30,tag:"Production"),.init(title:"Motive Green Homes",progress:0.42,tag:"Business"),.init(title:"Homeschool 2026–2027",progress:0.40,tag:"Education")]
        goals=[.init(title:"Grow My Businesses",progress:0.70),.init(title:"Pay Off Debt",progress:0.45),.init(title:"Take Family on Vacation",progress:0.30),.init(title:"Be a Better Father",progress:0.80),.init(title:"Financial Freedom",progress:0.25)]
        notes=[.init(title:"Ideas for new YouTube series",dateText:"Today at 8:12 AM"),.init(title:"Homeschool curriculum options",dateText:"Yesterday at 6:45 PM"),.init(title:"Equipment to purchase",dateText:"Sep 10, 2026"),.init(title:"Family vacation ideas",dateText:"Sep 9, 2026")]
    }
    func plan(){
        let p = tasks.filter{ !$0.completed && $0.priority }
        aiMessage = p.isEmpty ? "Your day is balanced. Start with the earliest unfinished task and keep a 30-minute buffer." : "Start with \(p[0].title), then move to the next priority before lower-impact work."
    }
}

let bg = Color(red:0.025,green:0.04,blue:0.075)
let panel = Color(red:0.045,green:0.068,blue:0.11)
let stroke = Color.white.opacity(0.09)
let purple = Color(red:0.39,green:0.24,blue:0.95)
let blue = Color(red:0.12,green:0.45,blue:1.0)
let green = Color(red:0.08,green:0.78,blue:0.38)
let pink = Color(red:1.0,green:0.20,blue:0.50)
let orange = Color(red:1.0,green:0.42,blue:0.08)

func hourText(_ h:Int)->String { let a = h < 12 ? "AM":"PM"; let x = h % 12 == 0 ? 12 : h % 12; return "\(x):00 \(a)" }
func tint(_ category:String)->Color { category=="Family" ? pink : category=="Business" ? green : category=="School" ? .teal : purple }

struct Card<Content:View>:View {
    let content:Content; init(@ViewBuilder _ content:()->Content){ self.content=content() }
    var body: some View { content.padding(14).background(panel.opacity(0.95)).overlay(RoundedRectangle(cornerRadius:14).stroke(stroke)).clipShape(RoundedRectangle(cornerRadius:14)) }
}

struct MountainScene: View {
    @State private var now = Date()
    var hour:Int { Calendar.current.component(.hour, from: now) }
    var sky:[Color] {
        switch hour { case 5..<10: return [Color.indigo.opacity(0.8),Color.orange.opacity(0.75),Color.yellow.opacity(0.4)]; case 10..<17: return [Color.blue.opacity(0.75),Color.cyan.opacity(0.4),Color.indigo.opacity(0.35)]; case 17..<20: return [Color.indigo.opacity(0.9),Color.pink.opacity(0.65),Color.orange.opacity(0.8)]; default: return [Color.black,Color.indigo.opacity(0.65),Color.blue.opacity(0.28)] }
    }
    var body: some View {
        TimelineView(.periodic(from:.now,by:60)) { context in
            ZStack {
                LinearGradient(colors: sky,startPoint:.topLeading,endPoint:.bottomTrailing)
                Circle().fill(hour >= 20 || hour < 5 ? Color.white.opacity(0.75) : Color.orange.opacity(0.85)).frame(width:70,height:70).blur(radius:2).offset(x:210,y:-28)
                MountainShape(seed:0).fill(Color.black.opacity(0.45)).offset(y:45)
                MountainShape(seed:1).fill(Color(red:0.04,green:0.11,blue:0.13).opacity(0.9)).offset(y:68)
                LinearGradient(colors:[Color.clear,Color.black.opacity(0.55)],startPoint:.top,endPoint:.bottom)
            }
            .onChange(of: context.date){ _,v in now=v }
        }
    }
}
struct MountainShape: Shape {
    let seed:Int
    func path(in r:CGRect)->Path { var p=Path(); p.move(to:CGPoint(x:0,y:r.height)); let points = seed==0 ? [0.0,0.13,0.25,0.37,0.52,0.67,0.8,1.0] : [0.0,0.18,0.33,0.48,0.62,0.77,1.0]; let heights = seed==0 ? [0.70,0.42,0.60,0.28,0.58,0.34,0.62,0.48] : [0.78,0.58,0.72,0.46,0.68,0.52,0.74]; for (i,x) in points.enumerated(){ p.addLine(to:CGPoint(x:r.width*x,y:r.height*heights[i])) }; p.addLine(to:CGPoint(x:r.width,y:r.height)); p.closeSubpath(); return p }
}

@main struct LifePlanProApp: App {
    @StateObject var store = PlannerStore()
    var body: some Scene {
        WindowGroup { RootView().environmentObject(store).preferredColorScheme(.dark).frame(minWidth:1240,minHeight:780) }
            .windowStyle(.hiddenTitleBar).windowToolbarStyle(.unifiedCompact)
    }
}

struct RootView: View {
    @EnvironmentObject var store:PlannerStore
    var body: some View {
        HStack(spacing:0){ Sidebar().frame(width:232); Divider().overlay(stroke); VStack(spacing:0){ TopBar(); Group { switch store.selected { case "Today": Dashboard(); case "Tasks": TasksView(); case "Projects": ProjectsView(); case "Goals": GoalsView(); case "Notes": NotesView(); default: Placeholder(title:store.selected) } } } }
            .background(bg).sheet(isPresented:$store.showAddTask){ AddTaskSheet() }.sheet(isPresented:$store.showAddEvent){ AddEventSheet() }
    }
}

struct Sidebar: View {
    @EnvironmentObject var store:PlannerStore
    let main=[("Today","house.fill"),("Calendar","calendar"),("Tasks","checkmark.square"),("Projects","folder"),("Goals","scope"),("Money","dollarsign.circle"),("Family","person.3"),("School","graduationcap"),("Notes","doc.text"),("Files","folder.fill"),("Contacts","person.crop.square"),("Planner Maker","rectangle.3.group"),("Templates","square.grid.2x2")]
    let tools=[("AI Planner","sparkles"),("Habit Tracker","heart"),("Meal Planner","fork.knife"),("Travel","airplane"),("Reports","chart.xyaxis.line")]
    var body: some View {
        VStack(alignment:.leading,spacing:10){
            HStack(spacing:10){ RoundedRectangle(cornerRadius:9).fill(LinearGradient(colors:[blue,purple,pink],startPoint:.topLeading,endPoint:.bottomTrailing)).frame(width:34,height:34).overlay(Image(systemName:"diamond.fill").rotationEffect(.degrees(45))); VStack(alignment:.leading,spacing:0){ HStack(spacing:2){ Text("LifePlan").font(.system(size:20,weight:.bold)); Text("Pro").font(.system(size:14,weight:.semibold)).foregroundStyle(.purple) }; Text("Plan Today. Build Tomorrow.").font(.caption2).foregroundStyle(.secondary) } }.padding(.horizontal,14).padding(.top,18).padding(.bottom,8)
            ScrollView(showsIndicators:false){ VStack(spacing:3){ ForEach(main,id:\.0){ item in nav(item.0,item.1) }; Text("Tools").font(.caption).foregroundStyle(.secondary).frame(maxWidth:.infinity,alignment:.leading).padding(.horizontal,14).padding(.top,12); ForEach(tools,id:\.0){ item in nav(item.0,item.1) } } }
            Button(action:{ store.aiMessage="A more organized you starts with one clear next action." }){ VStack(alignment:.leading,spacing:4){ Text("A More Organized You").bold(); Text("A Brighter Tomorrow.").foregroundStyle(.purple) }.font(.caption).frame(maxWidth:.infinity,alignment:.leading).padding(14).background(LinearGradient(colors:[purple.opacity(0.45),blue.opacity(0.22)],startPoint:.leading,endPoint:.trailing)).clipShape(RoundedRectangle(cornerRadius:14)).padding(12) }.buttonStyle(.plain)
        }.background(Color.black.opacity(0.16))
    }
    func nav(_ title:String,_ icon:String)->some View { Button { store.selected=title } label:{ HStack{ Image(systemName:icon).frame(width:24); Text(title); Spacer() }.padding(.vertical,9).padding(.horizontal,12).background(store.selected==title ? LinearGradient(colors:[purple,Color.purple],startPoint:.leading,endPoint:.trailing) : LinearGradient(colors:[Color.clear,Color.clear],startPoint:.leading,endPoint:.trailing)).clipShape(RoundedRectangle(cornerRadius:9)) }.buttonStyle(.plain).padding(.horizontal,8) }
}

struct TopBar: View {
    @EnvironmentObject var store:PlannerStore
    var body: some View { HStack{ Spacer(); HStack{ Image(systemName:"magnifyingglass").foregroundStyle(.secondary); TextField("Search anything… (tasks, events, notes, files, people…)",text:$store.search).textFieldStyle(.plain) }.padding(.horizontal,14).frame(width:540,height:34).background(Color.white.opacity(0.055)).overlay(Capsule().stroke(stroke)).clipShape(Capsule()); Spacer(); Image(systemName:"bell"); Image(systemName:"moon.stars").foregroundStyle(.purple); Circle().fill(LinearGradient(colors:[purple,pink],startPoint:.top,endPoint:.bottom)).frame(width:30,height:30).overlay(Text("M").bold()); VStack(alignment:.leading,spacing:0){ Text("Good Morning,").font(.caption2).foregroundStyle(.secondary); Text("Monty").font(.caption).bold() } }.padding(.horizontal,18).frame(height:54).background(Color.black.opacity(0.18)) }
}

struct Dashboard: View {
    @EnvironmentObject var store:PlannerStore
    var body: some View {
        ScrollView { VStack(spacing:10){
            ZStack(alignment:.leading){ MountainScene(); HStack{ VStack(alignment:.leading,spacing:3){ Text("Good Morning, Monty").font(.system(size:32,weight:.bold)); Text("Stay consistent. Great things take planned action.").font(.title3) }; Spacer(); VStack(alignment:.trailing,spacing:10){ Text(Date.now.formatted(date:.complete,time:.omitted)).font(.subheadline); Text("“A well planned day\ncreates a better tomorrow.”").italic().multilineTextAlignment(.trailing) } }.padding(22) }.frame(height:150).clipShape(RoundedRectangle(cornerRadius:16))
            HStack(spacing:9){ Metric(icon:"calendar",value:"\(store.events.count)",label:"Today's Events",color:blue); Metric(icon:"checkmark",value:"\(store.tasks.filter{!$0.completed}.count)",label:"Tasks Due",color:green); Metric(icon:"folder",value:"\(store.projects.count)",label:"Active Projects",color:purple); Metric(icon:"scope",value:"2",label:"Goals This Week",color:orange); Metric(icon:"person.2.fill",value:"Family",label:"2 upcoming",color:pink); Metric(icon:"graduationcap.fill",value:"School",label:"1 assignment",color:.teal); Metric(icon:"dollarsign",value:"1",label:"Bill Due",color:green) }
            HStack(alignment:.top,spacing:10){ CalendarCard().frame(maxWidth:.infinity); TasksCard().frame(maxWidth:.infinity); UpcomingCard().frame(maxWidth:.infinity); VStack(spacing:10){ AIPlannerCard(); GoalsCard() }.frame(width:245) }
            HStack(alignment:.top,spacing:10){ ProjectsCard().frame(maxWidth:.infinity); NotesCard().frame(maxWidth:.infinity) }
            AIBar()
        }.padding(12) }.background(bg)
    }
}

struct Metric: View { let icon,value,label:String; let color:Color; var body: some View { Card{ HStack{ RoundedRectangle(cornerRadius:9).fill(color.opacity(0.25)).frame(width:38,height:38).overlay(Image(systemName:icon).foregroundStyle(color)); VStack(alignment:.leading,spacing:2){ Text(value).font(.title3).bold(); Text(label).font(.caption2).foregroundStyle(.secondary) }; Spacer() } }.frame(maxWidth:.infinity) } }

struct CalendarCard: View {
    @EnvironmentObject var store:PlannerStore
    var body: some View { Card{ VStack(alignment:.leading,spacing:10){ Header(icon:"calendar",title:"Calendar",trailing:"Week"); HStack{ Text("September 2026").bold(); Spacer(); Image(systemName:"chevron.left"); Text("Today").font(.caption).padding(5).background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius:6)); Image(systemName:"chevron.right") }; HStack{ ForEach(["Sun","Mon","Tue","Wed","Thu","Fri","Sat"],id:\.self){ Text($0).font(.caption2).frame(maxWidth:.infinity) } }; HStack{ ForEach(["6","7","8","9","10","11","12"],id:\.self){ d in Text(d).font(.caption).frame(maxWidth:.infinity).padding(5).background(d=="12" ? purple:Color.clear).clipShape(Circle()) } }; Divider(); ForEach(store.events.prefix(5)){ e in HStack{ Text(hourText(e.startHour)).font(.caption2).frame(width:56,alignment:.leading).foregroundStyle(.secondary); RoundedRectangle(cornerRadius:5).fill(tint(e.category)).frame(width:7,height:28); Text(e.title).font(.caption).lineLimit(1); Spacer() }.padding(.vertical,2) }; Button("+ Add Event"){ store.showAddEvent=true }.buttonStyle(.plain).foregroundStyle(.purple) } } }
}
struct TasksCard: View {
    @EnvironmentObject var store:PlannerStore
    var body: some View { Card{ VStack(alignment:.leading,spacing:9){ Header(icon:"checkmark.square",title:"Tasks",trailing:"Today"); HStack{ Text("All (\(store.tasks.count))").font(.caption).padding(6).background(purple).clipShape(Capsule()); Text("High (\(store.tasks.filter{$0.priority && !$0.completed}.count))").font(.caption).padding(6).background(Color.red.opacity(0.18)).foregroundStyle(.red).clipShape(Capsule()); Spacer(); Button(action:{store.showAddTask=true}){Image(systemName:"plus")}.buttonStyle(.bordered) }; ForEach(store.tasks.prefix(6)){ t in HStack{ Button { if let i=store.tasks.firstIndex(where:{$0.id==t.id}){store.tasks[i].completed.toggle()} } label:{ Image(systemName:t.completed ? "checkmark.circle.fill":"circle").foregroundStyle(t.completed ? green:.white) }.buttonStyle(.plain); VStack(alignment:.leading,spacing:1){ Text(t.title).font(.caption).strikethrough(t.completed); Text(t.category).font(.caption2).foregroundStyle(tint(t.category)) }; Spacer(); Text(hourText(t.dueHour)).font(.caption2).foregroundStyle(.secondary) }.padding(.vertical,3) } } } }
}
struct UpcomingCard: View {
    let rows=[("Sun\nSep 13","Church Service","10:00 AM",Color.red),("Mon\nSep 14","Homeschool – Science","9:00 AM",blue),("Tue\nSep 15","Lawn Job – Snellville","8:00 AM",green),("Wed\nSep 16","Doctor Appointment","11:00 AM",purple),("Thu\nSep 17","Film Shoot Prep","2:00 PM",orange),("Fri\nSep 18","Kids Field Trip","9:00 AM",pink),("Sat\nSep 19","Family Day","All Day",green)]
    var body: some View { Card{ VStack(spacing:0){ Header(icon:"calendar.badge.clock",title:"Upcoming",trailing:"Next 7 Days"); ForEach(Array(rows.enumerated()),id:\.offset){ _,r in HStack{ Text(r.0).font(.caption2).frame(width:42,alignment:.leading); Circle().fill(r.3).frame(width:7,height:7); Text(r.1).font(.caption); Spacer(); Text(r.2).font(.caption2).foregroundStyle(.secondary) }.padding(.vertical,7); Divider().overlay(stroke) } } } }
struct AIPlannerCard: View {
    @EnvironmentObject var store:PlannerStore
    let prompts=["Plan my day","Break down a project","Create a schedule","Generate a meal plan","Organize my finances","Plan a homeschool month","Find time for this…"]
    var body: some View { Card{ VStack(alignment:.leading,spacing:6){ HStack{ Image(systemName:"sparkles").foregroundStyle(.pink); Text("AI Planner").bold(); Spacer(); Text("Pro").font(.caption2).padding(4).background(purple).clipShape(Capsule()) }; Text("How can I help you today?").font(.caption).foregroundStyle(.secondary); ForEach(prompts,id:\.self){ p in Button(p){ store.aiMessage = p=="Plan my day" ? "I'll prioritize urgent work, protect family time, and keep realistic buffers." : "I can help with \(p.lowercased())." }.buttonStyle(.plain).font(.caption).padding(6).frame(maxWidth:.infinity,alignment:.leading).background(Color.white.opacity(0.04)).clipShape(RoundedRectangle(cornerRadius:7)) }; if !store.aiMessage.isEmpty{ Text(store.aiMessage).font(.caption2).padding(8).background(purple.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius:8)) } } } }
struct GoalsCard: View {
    @EnvironmentObject var store:PlannerStore
    var body: some View { Card{ VStack(spacing:8){ Header(icon:"scope",title:"Life Goals",trailing:"View All"); ForEach(store.goals){ g in VStack(alignment:.leading,spacing:3){ HStack{Text(g.title).font(.caption);Spacer();Text("\(Int(g.progress*100))%").font(.caption2).foregroundStyle(.secondary)}; ProgressView(value:g.progress).tint(g.progress>0.65 ? green:purple) } } } }
}
struct ProjectsCard: View {
    @EnvironmentObject var store:PlannerStore
    var body: some View { Card{ VStack(alignment:.leading,spacing:9){ Header(icon:"folder.badge.gearshape",title:"Projects",trailing:"View All"); HStack{ ForEach(store.projects){ p in VStack(alignment:.leading,spacing:6){ Text(p.title).bold().font(.caption); Text(p.tag).font(.caption2).foregroundStyle(.secondary); ProgressView(value:p.progress).tint(purple); Text("\(Int(p.progress*100))%").font(.caption2).foregroundStyle(.secondary) }.padding(10).frame(maxWidth:.infinity,alignment:.leading).background(Color.white.opacity(0.035)).clipShape(RoundedRectangle(cornerRadius:9)) } } } } }
struct NotesCard: View {
    @EnvironmentObject var store:PlannerStore
    var body: some View { Card{ VStack(spacing:0){ Header(icon:"note.text",title:"Notes",trailing:"View All"); ForEach(store.notes){ n in HStack{ Image(systemName:"note.text").foregroundStyle(.yellow); VStack(alignment:.leading){Text(n.title).font(.caption);Text(n.dateText).font(.caption2).foregroundStyle(.secondary)};Spacer() }.padding(.vertical,7); Divider().overlay(stroke) } } } }
struct AIBar: View {
    @EnvironmentObject var store:PlannerStore; @State var text=""
    var body: some View { HStack{ Image(systemName:"sparkles").foregroundStyle(.purple); TextField("Tell AI what you want to do…",text:$text).textFieldStyle(.plain); Button("Plan My Day"){store.plan()}.buttonStyle(.bordered); Button("Go"){ store.aiMessage = text.isEmpty ? "Tell me what you want to organize." : "I turned \"\(text)\" into a next action."; text="" }.buttonStyle(.borderedProminent).tint(purple) }.padding(12).background(panel).overlay(RoundedRectangle(cornerRadius:13).stroke(Color.purple.opacity(0.3))).clipShape(RoundedRectangle(cornerRadius:13)) }
}
struct Header: View { let icon,title,trailing:String; var body: some View { HStack{ Image(systemName:icon).foregroundStyle(.purple); Text(title).font(.headline); Spacer(); Text(trailing).font(.caption).foregroundStyle(.secondary) } } }

struct TasksView: View { @EnvironmentObject var store:PlannerStore; var body: some View { VStack(alignment:.leading,spacing:16){ HStack{Text("Tasks").font(.largeTitle).bold();Spacer();Button("Add Task"){store.showAddTask=true}.buttonStyle(.borderedProminent).tint(purple)}; Card{ VStack{ ForEach(store.tasks){ t in HStack{ Button{ if let i=store.tasks.firstIndex(where:{$0.id==t.id}){store.tasks[i].completed.toggle()} } label:{Image(systemName:t.completed ? "checkmark.circle.fill":"circle").foregroundStyle(t.completed ? green:.white)}.buttonStyle(.plain); VStack(alignment:.leading){Text(t.title);Text(t.category).font(.caption).foregroundStyle(.secondary)};Spacer();Text(hourText(t.dueHour)).foregroundStyle(.secondary) }.padding(.vertical,8); Divider().overlay(stroke) } } };Spacer() }.padding(24).background(bg) } }
struct ProjectsView: View { @EnvironmentObject var store:PlannerStore; var body: some View { VStack(alignment:.leading,spacing:16){Text("Projects").font(.largeTitle).bold();LazyVGrid(columns:[GridItem(.adaptive(minimum:260),spacing:14)],spacing:14){ForEach(store.projects){p in Card{VStack(alignment:.leading,spacing:10){Text(p.title).font(.title3).bold();Text(p.tag).foregroundStyle(.secondary);ProgressView(value:p.progress).tint(purple);Text("\(Int(p.progress*100))% complete").font(.caption)}}}};Spacer()}.padding(24).background(bg) } }
struct GoalsView: View { var body: some View { VStack(alignment:.leading,spacing:16){Text("Goals").font(.largeTitle).bold();GoalsCard().frame(maxWidth:620);Spacer()}.padding(24).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading).background(bg) } }
struct NotesView: View { var body: some View { VStack(alignment:.leading,spacing:16){Text("Notes").font(.largeTitle).bold();NotesCard().frame(maxWidth:700);Spacer()}.padding(24).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading).background(bg) } }
struct Placeholder: View { let title:String; var body: some View { VStack(spacing:16){Image(systemName:"square.grid.2x2").font(.system(size:48)).foregroundStyle(.purple);Text(title).font(.largeTitle).bold();Text("This module is connected to the LifePlan Pro shell and ready for the next implementation pass.").foregroundStyle(.secondary)}.frame(maxWidth:.infinity,maxHeight:.infinity).background(bg) } }

struct AddTaskSheet: View {
    @EnvironmentObject var store:PlannerStore; @Environment(\.dismiss) var dismiss; @State var title=""; @State var category="Personal"; @State var hour=9; @State var priority=false
    var body: some View { VStack(alignment:.leading,spacing:16){Text("Add Task").font(.title2).bold();TextField("Task title",text:$title);Picker("Category",selection:$category){ForEach(["Personal","Work","Family","School"],id:\.self){Text($0)}};Stepper("Due: \(hourText(hour))",value:$hour,in:0...23);Toggle("High priority",isOn:$priority);HStack{Spacer();Button("Cancel"){dismiss()};Button("Add"){if !title.trimmingCharacters(in:.whitespaces).isEmpty{store.tasks.append(.init(title:title,category:category,dueHour:hour,priority:priority));dismiss()}}.buttonStyle(.borderedProminent).tint(purple)}}.padding(24).frame(width:420) }
}
struct AddEventSheet: View {
    @EnvironmentObject var store:PlannerStore; @Environment(\.dismiss) var dismiss; @State var title=""; @State var hour=9; @State var category="Work"
    var body: some View { VStack(alignment:.leading,spacing:16){Text("Add Event").font(.title2).bold();TextField("Event title",text:$title);Picker("Category",selection:$category){ForEach(["Work","Business","Family","School"],id:\.self){Text($0)}};Stepper("Start: \(hourText(hour))",value:$hour,in:0...23);HStack{Spacer();Button("Cancel"){dismiss()};Button("Add"){if !title.trimmingCharacters(in:.whitespaces).isEmpty{store.events.append(.init(title:title,startHour:hour,category:category));dismiss()}}.buttonStyle(.borderedProminent).tint(purple)}}.padding(24).frame(width:420) }
}
