#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
APP_NAME="LifePlan Pro"
PRODUCT="LifePlanPro"
DIST="$ROOT/dist"
APP="$DIST/${APP_NAME}.app"

echo "Building ${APP_NAME}..."
rm -rf "$DIST"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

python3 - <<'PY'
from pathlib import Path
src = Path('Sources/LifePlanPro/main.swift')
s = src.read_text()

# Compatibility fixes used by the macOS 13+ universal build.
s = s.replace('.onChange(of: context.date){ _,v in now=v }', '.onChange(of: context.date){ v in now=v }')
s = s.replace('func tint(_ category:String)->Color', 'func categoryColor(_ category:String)->Color')
s = s.replace('fill(tint(e.category))', 'fill(categoryColor(e.category))')
s = s.replace('foregroundStyle(tint(t.category))', 'foregroundStyle(categoryColor(t.category))')
s = s.replace('} } } }\nstruct AIPlannerCard', '} } } }\n}\nstruct AIPlannerCard')
s = s.replace('} } } }\nstruct GoalsCard', '} } } }\n}\nstruct GoalsCard')
s = s.replace('}\nstruct ProjectsCard', '}\n}\nstruct ProjectsCard')
s = s.replace('} } } } }\nstruct NotesCard', '} } } } }\n}\nstruct NotesCard')
s = s.replace('} } } }\nstruct AIBar', '} } } }\n}\nstruct AIBar')

# Add a persistent grocery model without changing the existing planner JSON format.
needle = '''struct PlannerNote: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var dateText: String
}
'''
addition = needle + '''
struct GroceryItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var category: String
    var quantity: Int
    var purchased = false
}
'''
if 'struct GroceryItem:' not in s:
    s = s.replace(needle, addition)

# Add grocery state and persistence to PlannerStore.
if '@Published var groceries:' not in s:
    s = s.replace(
        '    @Published var notes: [PlannerNote] = [] { didSet { save() } }',
        '    @Published var notes: [PlannerNote] = [] { didSet { save() } }\n    @Published var groceries: [GroceryItem] = [] { didSet { saveGroceries() } }'
    )
    s = s.replace(
        '        load()\n        loading = false',
        '        load()\n        loadGroceries()\n        loading = false'
    )
    marker = '    func plan() {'
    grocery_methods = '''    private var groceryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = base.appendingPathComponent("LifePlanPro", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("groceries.json")
    }

    func loadGroceries() {
        if let data = try? Data(contentsOf: groceryURL),
           let saved = try? JSONDecoder().decode([GroceryItem].self, from: data) {
            groceries = saved
        } else {
            groceries = [
                .init(name: "Milk", category: "Dairy", quantity: 1),
                .init(name: "Eggs", category: "Dairy", quantity: 1),
                .init(name: "Bananas", category: "Produce", quantity: 6),
                .init(name: "Chicken breast", category: "Meat", quantity: 2),
                .init(name: "Bread", category: "Bakery", quantity: 1)
            ]
        }
    }

    func saveGroceries() {
        guard !loading else { return }
        if let data = try? JSONEncoder().encode(groceries) {
            try? data.write(to: groceryURL, options: .atomic)
        }
    }

'''
    s = s.replace(marker, grocery_methods + marker)

# Replace Files with Grocery List throughout navigation.
s = s.replace('case "Files": FilesPage()', 'case "Grocery List": GroceryListPage()')
s = s.replace('("Files", "folder.fill")', '("Grocery List", "cart.fill")')
s = s.replace('Search anything… (tasks, events, notes, files, people…)', 'Search anything… (tasks, events, groceries, notes, people…)')

# Replace the Files page with a fully interactive Grocery List page.
old_files = '''struct FilesPage: View {
    var body: some View { PageShell("Files", subtitle: "Attach important documents to your plans and projects.") { ModuleGrid(items: [("Recent Files", "12", "doc"), ("Project Files", "18", "folder"), ("School Files", "9", "graduationcap"), ("Shared", "4", "person.2")]) } }
}
'''
new_grocery = '''struct GroceryListPage: View {
    @EnvironmentObject var store: PlannerStore
    @State private var newItem = ""
    @State private var quantity = 1
    @State private var category = "Produce"
    @State private var filter = "All"

    let categories = ["Produce", "Dairy", "Meat", "Bakery", "Pantry", "Frozen", "Drinks", "Household", "Other"]

    var visibleItems: [GroceryItem] {
        if filter == "All" { return store.groceries }
        if filter == "Needed" { return store.groceries.filter { !$0.purchased } }
        if filter == "Purchased" { return store.groceries.filter { $0.purchased } }
        return store.groceries.filter { $0.category == filter }
    }

    var body: some View {
        PageShell("Grocery List", subtitle: "Build, check off, and manage your shopping list.") {
            Card {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Add Grocery Item").font(.headline)
                    HStack(spacing: 10) {
                        TextField("Item name", text: $newItem)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { addItem() }
                        Picker("Category", selection: $category) {
                            ForEach(categories, id: \.self) { Text($0) }
                        }
                        .frame(width: 150)
                        Stepper("Qty \(quantity)", value: $quantity, in: 1...99)
                            .frame(width: 105)
                        Button("Add") { addItem() }
                            .buttonStyle(.borderedProminent)
                            .tint(accent)
                            .disabled(newItem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }

            HStack(spacing: 8) {
                ForEach(["All", "Needed", "Purchased"], id: \.self) { option in
                    Button(option) { filter = option }
                        .buttonStyle(.bordered)
                        .tint(filter == option ? accent : Color.secondary)
                }
                Menu("Category") {
                    ForEach(categories, id: \.self) { value in
                        Button(value) { filter = value }
                    }
                }
                Spacer()
                Text("\(store.groceries.filter { !$0.purchased }.count) needed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Clear Purchased") {
                    store.groceries.removeAll { $0.purchased }
                }
                .buttonStyle(.bordered)
                .disabled(!store.groceries.contains(where: { $0.purchased }))
            }

            Card {
                VStack(spacing: 0) {
                    if visibleItems.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "cart").font(.system(size: 34)).foregroundStyle(accent)
                            Text("No grocery items here yet.").font(.headline)
                            Text("Add an item above to start your list.").font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 46)
                    } else {
                        ForEach(visibleItems) { item in
                            HStack(spacing: 12) {
                                Button {
                                    if let i = store.groceries.firstIndex(where: { $0.id == item.id }) {
                                        store.groceries[i].purchased.toggle()
                                    }
                                } label: {
                                    Image(systemName: item.purchased ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(item.purchased ? green : Color.secondary)
                                }
                                .buttonStyle(.plain)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .strikethrough(item.purchased)
                                        .foregroundStyle(item.purchased ? Color.secondary : Color.primary)
                                    Text(item.category).font(.caption).foregroundStyle(accent)
                                }
                                Spacer()
                                Text("Qty \(item.quantity)")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(accent.opacity(0.10))
                                    .clipShape(Capsule())
                                Button(role: .destructive) {
                                    store.groceries.removeAll { $0.id == item.id }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 10)
                            Divider()
                        }
                    }
                }
            }
            .frame(maxWidth: 900)
        }
    }

    private func addItem() {
        let clean = newItem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        store.groceries.append(.init(name: clean, category: category, quantity: quantity))
        newItem = ""
        quantity = 1
    }
}
'''
if old_files in s:
    s = s.replace(old_files, new_grocery)

# Make the entire macOS window freely resizable while preserving access to dense dashboard content.
s = s.replace('.frame(minWidth: 1260, minHeight: 820)', '.frame(minWidth: 900, minHeight: 620)')
s = s.replace('Sidebar().frame(width: 230)', 'Sidebar().frame(minWidth: 190, idealWidth: 220, maxWidth: 240)')
s = s.replace('.frame(width: 520, height: 34)', '.frame(minWidth: 240, idealWidth: 420, maxWidth: 520, minHeight: 34, idealHeight: 34, maxHeight: 34)')

# Swift treats a file literally named main.swift as a top-level entry point, which conflicts with @main.
Path('Sources/LifePlanPro/App.swift').write_text(s)
src.unlink()
PY

if swift build -c release --arch x86_64 --arch arm64; then
  BIN_DIR="$(swift build -c release --arch x86_64 --arch arm64 --show-bin-path)"
else
  echo "Universal build unavailable on this runner; falling back to native architecture."
  swift build -c release
  BIN_DIR="$(swift build -c release --show-bin-path)"
fi

cp "$BIN_DIR/$PRODUCT" "$APP/Contents/MacOS/$PRODUCT"
chmod +x "$APP/Contents/MacOS/$PRODUCT"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>LifePlan Pro</string>
<key>CFBundleDisplayName</key><string>LifePlan Pro</string>
<key>CFBundleIdentifier</key><string>com.motive.lifeplanpro</string>
<key>CFBundleExecutable</key><string>LifePlanPro</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.2.0</string>
<key>CFBundleVersion</key><string>2</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
</dict></plist>
PLIST

codesign --force --deep --sign - "$APP"
cd "$DIST"
ditto -c -k --sequesterRsrc --keepParent "${APP_NAME}.app" "LifePlan-Pro-macOS.zip"
echo "Built: $APP"
