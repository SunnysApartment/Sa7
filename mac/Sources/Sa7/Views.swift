import SwiftUI

private let red = Color(red: 0.83, green: 0.08, blue: 0.17)

struct MenuView: View {
    @EnvironmentObject var state: AppState
    @ObservedObject var updater = Updater.shared

    var body: some View {
        let t = state.t, key = "\u{2066}\(state.shortcutLabel)\u{2069}"
        Text(state.status)
        if let version = updater.available {
            Button(updater.installing ? t("Updating…", "بيتحدّث…") : t("Update to \(version)", "حدّث لنسخة \(version)")) {
                _ = updater.install()
            }
            .disabled(updater.installing)
        }
        Divider()
        Button(t("Fix clipboard", "صلّح اللي في الحافظة")) { state.fixClipboard() }
        Divider()
        Toggle(t("Switch keyboard after fixing", "غيّر الكيبورد بعد التصليح"), isOn: $state.switchKeyboard)
        Toggle(t("Open Sa7 at login", "افتح Sa7 مع تشغيل الماك"), isOn: $state.launchAtLogin)
        Button(t("Shortcut: ", "الاختصار: ") + key) { state.showSetup() }
        Button(t("Settings…", "الإعدادات…")) { state.showSettings() }.keyboardShortcut(",")
        Button(t("Setup and practice…", "الإعداد والتجربة…")) { state.showSetup() }
        Picker(t("Language", "اللغة"), selection: $state.language) {
            Text("English").tag("en")
            Text("العربية").tag("ar")
        }
        Divider()
        Button(t("Quit Sa7", "اقفل Sa7")) { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}

/// General, Never flip, Apps, Typing, Updates. Everything here is stored in Sa7's preferences file only.
struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var rules: AppRules
    @EnvironmentObject var updater: Updater

    var body: some View {
        let t = state.t
        TabView {
            general.tabItem { Label(t("General", "عام"), systemImage: "gearshape") }
            neverFlip.tabItem { Label(t("Never flip", "ما تقلبش"), systemImage: "lock") }
            apps.tabItem { Label(t("Apps", "البرامج"), systemImage: "square.grid.2x2") }
            typing.tabItem { Label(t("Typing", "أثناء الكتابة"), systemImage: "keyboard") }
            updates.tabItem { Label(t("Updates", "التحديثات"), systemImage: "arrow.down.circle") }
        }
        .padding(20)
        .frame(width: 540, height: 440)
        .environment(\.layoutDirection, state.language == "ar" ? .rightToLeft : .leftToRight)
    }

    private var general: some View {
        let t = state.t
        return Form {
            Picker(t("Language", "اللغة"), selection: $state.language) {
                Text("English").tag("en")
                Text("العربية").tag("ar")
            }
            HStack {
                Text(t("Shortcut", "الاختصار"))
                Spacer()
                Text("\u{2066}\(state.shortcutLabel)\u{2069}").font(.body.monospaced())
                Button(state.recording ? t("Press the new shortcut, or Esc", "اضغط الاختصار الجديد، أو Esc") : t("Change", "غيّر")) {
                    state.recording ? state.stopRecording() : state.startRecording()
                }
            }
            Toggle(t("Switch keyboard after fixing", "غيّر الكيبورد بعد التصليح"), isOn: $state.switchKeyboard)
            Toggle(t("Open Sa7 at login", "افتح Sa7 مع تشغيل الماك"), isOn: $state.launchAtLogin)
            Toggle(t("Show a bubble with the fix", "اعرض فقاعة فيها التصليح"), isOn: $state.bubble)
            Toggle(t("Play a soft sound", "شغّل صوت خفيف"), isOn: $state.sound).disabled(!state.bubble)
            Text(t("Press the shortcut again right after a fix to put the text back.",
                   "اضغط الاختصار تاني بعد التصليح على طول علشان ترجّع الكلام زي ما كان."))
                .font(.callout).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }

    private var neverFlip: some View {
        let t = state.t
        return VStack(alignment: .leading, spacing: 10) {
            Text(t("Words Sa7 always leaves as they are, like names and brands. One per line, or separated by commas.",
                   "كلمات Sa7 عمره ما يقلبها، زي الأسامي والماركات. كل كلمة في سطر، أو افصل بينهم بفاصلة."))
                .fixedSize(horizontal: false, vertical: true)
            TextEditor(text: $state.keepText)
                .font(.body)
                .environment(\.layoutDirection, .leftToRight)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
        }
        .padding(8)
    }

    private var apps: some View {
        let t = state.t
        return VStack(alignment: .leading, spacing: 10) {
            Text(t("Sa7 stays off in these apps, and \(state.shortcutLabel) goes to the app instead.",
                   "Sa7 بيقف في البرامج دي، والاختصار بيوصل للبرنامج نفسه."))
                .fixedSize(horizontal: false, vertical: true)
            List {
                if rules.excluded.isEmpty {
                    Text(t("No apps yet.", "لسه مفيش برامج.")).foregroundStyle(.secondary)
                }
                ForEach(rules.excluded) { app in
                    HStack {
                        Image(nsImage: app.icon).resizable().frame(width: 20, height: 20)
                        Text(app.name)
                        Spacer()
                        Button(t("Remove", "شيل")) { rules.include(app.bundleID) }
                    }
                }
            }
            .frame(minHeight: 200)
            HStack {
                Menu(t("Add a running app", "ضيف برنامج مفتوح")) {
                    ForEach(rules.runningApps().filter { !rules.isExcluded($0.bundleID) }) { app in
                        Button(app.name) { rules.exclude(app) }
                    }
                }
                .fixedSize()
                Button(t("Choose…", "اختار…")) { if let app = rules.chooseApp() { rules.exclude(app) } }
            }
        }
        .padding(8)
    }

    private var typing: some View {
        let t = state.t
        return Form {
            Toggle(t("Notice wrong words while I type", "نبّهني للكلام الغلط وأنا بكتب"), isOn: $state.typingHints)
            Text(t("When Sa7 spots a word typed on the wrong keyboard, a small hint shows the right word. Press \(state.shortcutLabel) to fix it. Sa7 never changes text by itself. It only looks at the word you're typing, in memory, and stores nothing.",
                   "لما Sa7 يلاقي كلمة اتكتبت بالكيبورد الغلط، هيطلعلك فقاعة صغيرة فيها الكلمة الصح، واضغط الاختصار علشان تتصلّح. Sa7 عمره ما يغيّر الكلام لوحده، وبيبص بس على الكلمة اللي بتكتبها، في الذاكرة، ومش بيحفظ حاجة."))
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if state.typingHints && !state.typingPermission {
                HStack {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                    Text(t("macOS needs to allow Sa7 under Input Monitoring.", "الماك محتاج يسمح لـ Sa7 تحت Input Monitoring."))
                    Spacer()
                    Button(t("Open Settings", "افتح الإعدادات")) { state.openInputMonitoringSettings() }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var updates: some View {
        let t = state.t
        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        return Form {
            Toggle(t("Check for updates once a day", "دوّر على تحديثات مرة في اليوم"), isOn: $updater.enabled)
            Text(t("Off by default. When on, Sa7 asks GitHub for the latest version number and nothing else.",
                   "مقفول من الأول. لما تشغّله، Sa7 بيسأل GitHub على رقم آخر نسخة بس، ومش بيبعت أي حاجة تانية."))
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                if let version = updater.available {
                    Text(t("Version \(version) is available.", "نسخة \(version) نزلت."))
                    Spacer()
                    Button(updater.installing ? t("Updating…", "بيتحدّث…") : t("Update now", "حدّث دلوقتي")) { _ = updater.install() }
                        .disabled(updater.installing)
                } else {
                    Text(t("You have version \(current).", "معاك نسخة \(current)."))
                    Spacer()
                    Button(t("Check now", "دوّر دلوقتي")) { Task { await updater.checkIfDue(force: true) } }
                }
            }
            if let error = updater.errorMessage {
                Text(error).font(.callout).foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
    }
}

struct SetupView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        let t = state.t, key = "\u{2066}\(state.shortcutLabel)\u{2069}" // isolate keeps ⌃K in order inside Arabic text
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("Sa7", "صح")).font(.system(size: 34, weight: .bold))
                    Text(t("Typed with the wrong keyboard? Select the text and press your shortcut.",
                           "كتبت بالكيبورد الغلط؟ حدّد الكلام واضغط اختصارك."))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Picker("", selection: $state.language) {
                    Text("English").tag("en")
                    Text("العربية").tag("ar")
                }
                .labelsHidden()
                .fixedSize()
            }

            step(1, done: state.trusted,
                 title: state.trusted ? t("Permission is on", "الصلاحية مفعّلة")
                                      : t("Let Sa7 use the keyboard", "اسمح لـ Sa7 يستخدم الكيبورد")) {
                if !state.trusted {
                    Text(t("Sa7 needs Accessibility permission to copy the selected text and paste the fix in its place. Turn Sa7 on in the list that opens; this window updates by itself.",
                           "محتاج صلاحية Accessibility علشان ينسخ الكلام المحدد ويلصق الصح مكانه. فعّل Sa7 في القايمة اللي هتفتح، والشاشة دي هتتحدّث لوحدها."))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button(t("Open Settings", "افتح الإعدادات")) { state.askForPermission() }
                        Button(t("Reset permission", "صفّر الصلاحية")) { state.resetPermission() }
                    }
                    Text(t("Sa7 is already on in the list but this step stays unticked? That happens after an update from an older version. Click Reset permission, then turn Sa7 on again.",
                           "Sa7 متفعّل في القايمة والخطوة دي لسه مش متعلّم عليها؟ ده بيحصل بعد التحديث من نسخة قديمة. اضغط صفّر الصلاحية، وبعدين فعّل Sa7 تاني."))
                        .font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            step(2, done: !state.keyboards.isEmpty,
                 title: state.keyboards.isEmpty ? t("Add an Arabic keyboard", "ضيف كيبورد عربي")
                                                : t("Keyboards: ", "الكيبوردات: ") + state.keyboards) {
                if state.keyboards.isEmpty {
                    Text(t("In System Settings, open Keyboard, then Text Input, click Edit and add Arabic.",
                           "من System Settings افتح Keyboard، وبعدين Text Input، واضغط Edit وضيف Arabic."))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            step(3, done: true, title: t("Shortcut: ", "الاختصار: ") + key) {
                Button(state.recording ? t("Press the new shortcut, or Esc to cancel", "اضغط الاختصار الجديد، أو Esc للإلغاء")
                                       : t("Change shortcut", "غيّر الاختصار")) {
                    state.recording ? state.stopRecording() : state.startRecording()
                }
            }

            step(4, done: false, title: t("Try it", "جرّب")) {
                Text(t("Select all of this text and press \(state.shortcutLabel).",
                       "حدّد الكلام ده كله واضغط \(key)."))
                TextField("", text: $state.practice).textFieldStyle(.roundedBorder)
                Text(state.status).font(.callout).foregroundStyle(.secondary)
            }
        }
        .padding(28)
        .frame(width: 440)
        .environment(\.layoutDirection, state.language == "ar" ? .rightToLeft : .leftToRight)
    }

    private func step<Content: View>(_ number: Int, done: Bool, title: String,
                                     @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "\(number).circle")
                .font(.title2)
                .foregroundStyle(done ? red : .secondary)
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.headline)
                content()
            }
        }
    }
}
