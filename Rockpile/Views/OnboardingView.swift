import SwiftUI

struct OnboardingView: View {
    @State private var setup = SetupManager()
    @State private var step: Step = .language
    @State private var selectedRole: Role?
    @State private var pairingInput: String = ""
    @State private var pairingError: String?
    @State private var showCopied = false

    // Dual O₂ settings (v2.0)
    @State private var localO2Mode: String = AppSettings.localOxygenMode
    @State private var localTankCapacity: Int = AppSettings.localOxygenTankCapacity
    @State private var remoteO2Mode: String = AppSettings.remoteOxygenMode
    @State private var remoteTankCapacity: Int = AppSettings.remoteOxygenTankCapacity
    @State private var remoteEnabled: Bool = AppSettings.remoteEnabled

    // Usage API settings (v2.1)
    @State private var localProvider: String = AppSettings.localProvider
    @State private var remoteProvider: String = AppSettings.remoteProvider
    @State private var localAdminKey: String = ""
    @State private var remoteAdminKey: String = ""
    @State private var localTeamId: String = AdminKeyManager.readTeamId(creature: .hermitCrab) ?? ""
    @State private var remoteTeamId: String = AdminKeyManager.readTeamId(creature: .crawfish) ?? ""
    @State private var localAPITest: APITestState = .idle
    @State private var remoteAPITest: APITestState = .idle

    // Language refresh
    @State private var languageRefresh = 0

    enum APITestState: Equatable {
        case idle, testing, success, failed(String)
    }

    // Update flow
    @State private var showingUpdateSummary: Bool
    @State private var autoCompletePhase: AutoCompletePhase = .idle

    var onComplete: () -> Void

    enum Step: Equatable { case language, roleAndWelcome, configAndO2, installAndTest }

    enum Role: String, CaseIterable {
        case local   = "local"
        case monitor = "monitor"
        case host    = "host"
    }

    enum AutoCompletePhase: Equatable {
        case idle, installing, testing, done, failed(String)
    }

    init(isUpdate: Bool = false, onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        self._showingUpdateSummary = State(initialValue: isUpdate)

        // Pre-fill from saved settings
        let savedRole = AppSettings.setupRole
        if let role = Role(rawValue: savedRole) {
            self._selectedRole = State(initialValue: role)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if showingUpdateSummary {
                updateSummaryView
            } else {
                progressBar.padding(.top, 16).padding(.horizontal, 24)

                Group {
                    switch step {
                    case .language:       languageSelectionView
                    case .roleAndWelcome: roleAndWelcomeView
                    case .configAndO2:    configAndO2View
                    case .installAndTest: installAndTestView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.25), value: step)
            }
        }
        .frame(width: 460, height: 560)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { setup.detectRockpile() }
        .id(languageRefresh)
    }

    // MARK: - Progress (4 Steps)

    private var progressBar: some View {
        let steps: [Step] = [.language, .roleAndWelcome, .configAndO2, .installAndTest]
        let idx = steps.firstIndex(of: step) ?? 0
        return HStack(spacing: 4) {
            ForEach(0..<steps.count, id: \.self) { i in
                Capsule()
                    .fill(i <= idx ? Color.accentColor : Color.gray.opacity(0.25))
                    .frame(height: 3)
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 步骤 0: 语言选择
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var languageSelectionView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
            Text("Rockpile").font(.system(size: 28, weight: .bold))
            Text("🐚 + 🦞 — Your Notch Bar Companions")
                .font(.system(size: 13)).foregroundColor(.secondary)

            Spacer().frame(height: 12)

            Text(L10n.s("onboard.selectLanguage"))
                .font(.system(size: 16, weight: .medium))

            VStack(spacing: 10) {
                ForEach(AppLanguage.allCases, id: \.rawValue) { lang in
                    languageCard(lang)
                }
            }
            .padding(.horizontal, 60)

            Spacer()

            HStack {
                Spacer()
                Button(L10n.s("onboard.next")) {
                    step = .roleAndWelcome
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
            }
            .padding(.horizontal, 24).padding(.bottom, 20)
        }
    }

    private func languageCard(_ lang: AppLanguage) -> some View {
        let isSelected = L10n.language == lang
        return Button {
            AppSettings.appLanguage = lang.rawValue
            languageRefresh += 1
        } label: {
            HStack(spacing: 12) {
                Text(lang.flag)
                    .font(.system(size: 24))
                Text(lang.displayName)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.2),
                            lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 路径 B: 版本更新摘要
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var updateSummaryView: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 28)

            // Logo + version
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 56, height: 56)
            Text("Rockpile v\(AppSettings.currentAppVersion)")
                .font(.system(size: 22, weight: .bold))
                .padding(.top, 6)

            Spacer().frame(height: 20)

            // What's new
            VStack(alignment: .leading, spacing: 8) {
                Label(L10n.s("onboard.thisUpdate"), systemImage: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 5) {
                    ForEach(AppSettings.versionNotes, id: \.self) { note in
                        HStack(alignment: .top, spacing: 6) {
                            Text("·")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.accentColor)
                            Text(note)
                                .font(.system(size: 12))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor.opacity(0.15), lineWidth: 1))
            .padding(.horizontal, 28)

            Spacer().frame(height: 16)

            // Current settings summary
            VStack(alignment: .leading, spacing: 8) {
                Label(L10n.s("onboard.currentSettings"), systemImage: "gearshape")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)

                VStack(spacing: 6) {
                    settingSummaryRow(L10n.s("settings.mode"), roleName(AppSettings.setupRole))
                    settingSummaryRow("🐚 " + L10n.s("settings.localO2"),
                        "\(AppSettings.isLocalClaudeMode ? L10n.s("settings.claudeQuota") : L10n.s("settings.paidUsage")) / \(TokenTracker.formatTokens(AppSettings.localOxygenTankCapacity))")
                    if AppSettings.remoteEnabled {
                        settingSummaryRow("🦞 " + L10n.s("settings.remoteO2"),
                            "\(AppSettings.isRemotePaidMode ? L10n.s("settings.paidUsage") : L10n.s("settings.claudeQuota")) / \(TokenTracker.formatTokens(AppSettings.remoteOxygenTankCapacity))")
                    }
                    if !AppSettings.rockpileHost.isEmpty {
                        settingSummaryRow(L10n.s("settings.remoteHost"), AppSettings.rockpileHost)
                    }
                    if let ip = SetupManager.getLocalIP() {
                        settingSummaryRow(L10n.s("settings.localIP"), ip)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.15), lineWidth: 1))
            .padding(.horizontal, 28)

            Spacer()

            // Auto-complete status
            if autoCompletePhase != .idle {
                autoCompleteStatusView
                    .padding(.horizontal, 28).padding(.bottom, 8)
            }

            // Buttons
            HStack {
                Button(L10n.s("onboard.reconfigure")) {
                    showingUpdateSummary = false
                    step = .language
                }
                .buttonStyle(.bordered)

                Spacer()

                switch autoCompletePhase {
                case .idle:
                    Button(L10n.s("onboard.keepSettings")) {
                        startQuickUpdate()
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large)

                case .installing, .testing:
                    Button(L10n.s("onboard.processing")) {}
                        .buttonStyle(.borderedProminent).controlSize(.large)
                        .disabled(true)

                case .done:
                    Button(L10n.s("onboard.start")) {
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large)

                case .failed:
                    HStack(spacing: 8) {
                        Button(L10n.s("onboard.retry")) { startQuickUpdate() }
                            .buttonStyle(.bordered)
                        Button(L10n.s("onboard.openSettings")) {
                            showingUpdateSummary = false
                            step = .language
                        }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                    }
                }
            }
            .padding(.horizontal, 28).padding(.bottom, 20)
        }
    }

    private var autoCompleteStatusView: some View {
        HStack(spacing: 8) {
            switch autoCompletePhase {
            case .installing:
                ProgressView().controlSize(.small)
                Text(L10n.s("onboard.installing")).font(.system(size: 12)).foregroundColor(.secondary)
            case .testing:
                ProgressView().controlSize(.small)
                Text(L10n.s("onboard.testingConn")).font(.system(size: 12)).foregroundColor(.secondary)
            case .done:
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                Text(L10n.s("onboard.allReady")).font(.system(size: 12, weight: .medium)).foregroundColor(.green)
            case .failed(let err):
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                Text(err).font(.system(size: 11)).foregroundColor(.orange).lineLimit(2)
            case .idle:
                EmptyView()
            }
            Spacer()
        }
    }

    private func startQuickUpdate() {
        Task { @MainActor in
            // Phase 1: Install
            autoCompletePhase = .installing
            PluginInstaller.installIfNeeded()

            try? await Task.sleep(for: .milliseconds(300))

            // Phase 2: Skip test for monitor/host — only test local mode
            let role = AppSettings.setupRole
            if role == "host" || role == "monitor" {
                AppSettings.setupCompleted = true
                autoCompletePhase = .done
                try? await Task.sleep(for: .seconds(1))
                onComplete()
                return
            }

            // Local mode: test connection, but complete even if it fails
            autoCompletePhase = .testing
            await setup.testConnection(host: "localhost")

            AppSettings.setupCompleted = true
            switch setup.connectionTestResult {
            case .success:
                autoCompletePhase = .done
                try? await Task.sleep(for: .seconds(1.5))
                onComplete()
            default:
                autoCompletePhase = .done
                try? await Task.sleep(for: .seconds(1))
                onComplete()
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 步骤 1: 欢迎 + 角色选择
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var roleAndWelcomeView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
            Text("Rockpile").font(.system(size: 26, weight: .bold))
            Text("🐚 \(L10n.s("creature.hermitCrab")) + 🦞 \(L10n.s("creature.crawfish"))")
                .font(.system(size: 13)).foregroundColor(.secondary)

            Spacer().frame(height: 4)

            Text(L10n.s("onboard.roleQuestion")).font(.system(size: 14, weight: .medium))

            VStack(spacing: 8) {
                roleCard(.local,
                         icon: "house.fill",
                         title: L10n.s("onboard.roleLocal"),
                         desc: L10n.s("onboard.roleLocalDesc"),
                         disabled: !setup.isRockpileDetected)
                roleCard(.monitor,
                         icon: "display",
                         title: L10n.s("onboard.roleMonitor"),
                         desc: L10n.s("onboard.roleMonitorDesc"))
                roleCard(.host,
                         icon: "leaf.fill",
                         title: L10n.s("onboard.roleHost"),
                         desc: L10n.s("onboard.roleHostDesc"))
            }
            .padding(.horizontal, 24)

            Spacer()

            navButtons(back: { step = .language }) { step = .configAndO2 }
                .disabled(selectedRole == nil)
        }
        .onAppear {
            // Auto-select local if Rockpile detected and no prior selection
            if selectedRole == nil && setup.isRockpileDetected {
                selectedRole = .local
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 步骤 2: 配置 + O₂ 设置
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var configAndO2View: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    Spacer().frame(height: 8)

                    // Role-specific config
                    switch selectedRole {
                    case .local:   configLocal
                    case .monitor: configMonitor
                    case .host:    configHost
                    case .none:    EmptyView()
                    }

                    // Divider
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 1)
                        .padding(.horizontal, 32)

                    // O₂ settings
                    o2ConfigSection

                    Spacer().frame(height: 12)
                }
            }

            navButtons(back: { step = .roleAndWelcome }) { performInstall() }
                .disabled(selectedRole == .monitor && decodedIP == nil)
                .padding(.top, 8)
                .padding(.bottom, 4)
        }
    }

    // — Dual O₂ Config Section (v2.0)
    private var o2ConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ── Local O₂ (寄居蟹) ──
            if selectedRole == .local {
                HStack(spacing: 6) {
                    Text("🐚")
                        .font(.system(size: 14))
                    Text(L10n.s("settings.localO2"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DS.Semantic.localAccent)
                }
                .padding(.horizontal, 32)

                o2ModeRow(mode: $localO2Mode)
                    .padding(.horizontal, 32)

                o2CapacityRow(capacity: $localTankCapacity)
                    .padding(.horizontal, 32)

                if localO2Mode == "paid" {
                    usageAPIConfigSection(
                        creature: .hermitCrab,
                        provider: $localProvider,
                        adminKey: $localAdminKey,
                        teamId: $localTeamId,
                        testState: $localAPITest
                    )
                    .padding(.horizontal, 32)
                }
            }

            // ── Remote O₂ (小龙虾) ──
            if selectedRole == .local {
                // Remote toggle
                HStack(spacing: 6) {
                    Toggle(isOn: $remoteEnabled) {
                        HStack(spacing: 6) {
                            Text("🦞")
                                .font(.system(size: 14))
                            Text(L10n.s("settings.remoteO2"))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(DS.Semantic.remoteAccent)
                        }
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }
                .padding(.horizontal, 32)

                if remoteEnabled {
                    o2ModeRow(mode: $remoteO2Mode)
                        .padding(.horizontal, 32)

                    o2CapacityRow(capacity: $remoteTankCapacity)
                        .padding(.horizontal, 32)

                    if remoteO2Mode == "paid" {
                        usageAPIConfigSection(
                            creature: .crawfish,
                            provider: $remoteProvider,
                            adminKey: $remoteAdminKey,
                            teamId: $remoteTeamId,
                            testState: $remoteAPITest
                        )
                        .padding(.horizontal, 32)
                    }
                }
            } else {
                // Monitor mode: single O₂ config
                HStack(spacing: 6) {
                    Image(systemName: "bubbles.and.sparkles")
                        .font(.system(size: 14))
                        .foregroundColor(.cyan)
                    Text("O₂")
                        .font(.system(size: 14, weight: .semibold))
                }
                .padding(.horizontal, 32)

                o2ModeRow(mode: $remoteO2Mode)
                    .padding(.horizontal, 32)

                o2CapacityRow(capacity: $remoteTankCapacity)
                    .padding(.horizontal, 32)
            }

            Text(L10n.s("onboard.o2Hint"))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
        }
    }

    private func o2ModeRow(mode: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.s("onboard.meterMode"))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            HStack(spacing: 6) {
                o2ModeButton(L10n.s("settings.claudeQuota"), isActive: mode.wrappedValue == "claude") {
                    mode.wrappedValue = "claude"
                }
                o2ModeButton(L10n.s("settings.paidUsage"), isActive: mode.wrappedValue == "paid") {
                    mode.wrappedValue = "paid"
                }
            }
        }
    }

    private func o2CapacityRow(capacity: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.s("settings.bottleCapacity"))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            HStack(spacing: 6) {
                ForEach([500_000, 1_000_000, 2_000_000, 5_000_000], id: \.self) { cap in
                    o2ModeButton(TokenTracker.formatTokens(cap),
                                 isActive: capacity.wrappedValue == cap) {
                        capacity.wrappedValue = cap
                    }
                }
            }
        }
    }

    // — Usage API Config (v2.1)
    private func usageAPIConfigSection(
        creature: CreatureType,
        provider: Binding<String>,
        adminKey: Binding<String>,
        teamId: Binding<String>,
        testState: Binding<APITestState>
    ) -> some View {
        let providers: [(String, String)] = [
            (AIProvider.claudeAPI.rawValue, "Anthropic API"),
            (AIProvider.openAI.rawValue, "OpenAI"),
            (AIProvider.xAI.rawValue, "xAI"),
        ]
        let selectedProvider = AIProvider(rawValue: provider.wrappedValue)

        return VStack(alignment: .leading, spacing: 8) {
            Text(L10n.s("onboard.usageAPI"))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            // Provider picker
            HStack(spacing: 6) {
                ForEach(providers, id: \.0) { (value, label) in
                    o2ModeButton(label, isActive: provider.wrappedValue == value) {
                        provider.wrappedValue = value
                        testState.wrappedValue = .idle
                    }
                }
            }

            // Admin Key input
            if let sp = selectedProvider, sp.supportsUsageAPI {
                SecureField(sp.adminKeyDescription, text: adminKey)
                    .font(.system(size: 12))
                    .textFieldStyle(.roundedBorder)

                // Team ID for xAI
                if sp.needsTeamId {
                    TextField("Team ID", text: teamId)
                        .font(.system(size: 12))
                        .textFieldStyle(.roundedBorder)
                }

                // Test button + status
                HStack(spacing: 8) {
                    Button {
                        testAPIConnection(creature: creature, provider: sp,
                                          adminKey: adminKey.wrappedValue,
                                          teamId: teamId.wrappedValue,
                                          testState: testState)
                    } label: {
                        Label(L10n.s("onboard.testConn"), systemImage: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(adminKey.wrappedValue.isEmpty || testState.wrappedValue == .testing)

                    switch testState.wrappedValue {
                    case .idle:
                        EmptyView()
                    case .testing:
                        ProgressView().controlSize(.mini)
                        Text(L10n.s("onboard.verifying")).font(.system(size: 11)).foregroundColor(.secondary)
                    case .success:
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        Text(L10n.s("onboard.valid")).font(.system(size: 11, weight: .medium)).foregroundColor(.green)
                    case .failed(let msg):
                        Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                        Text(msg).font(.system(size: 11)).foregroundColor(.red).lineLimit(1)
                    }
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.03)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor.opacity(0.1), lineWidth: 1))
    }

    private func testAPIConnection(
        creature: CreatureType,
        provider: AIProvider,
        adminKey: String,
        teamId: String,
        testState: Binding<APITestState>
    ) {
        testState.wrappedValue = .testing

        // Temporarily store provider + key so queryNow() can find them
        if creature == .hermitCrab {
            AppSettings.localProvider = provider.rawValue
        } else {
            AppSettings.remoteProvider = provider.rawValue
        }
        AdminKeyManager.storeKey(for: provider, creature: creature, key: adminKey)
        if provider.needsTeamId {
            AdminKeyManager.storeTeamId(teamId, creature: creature)
        }

        Task {
            await UsageQueryService.shared.queryNow(for: creature)
            let error = creature == .hermitCrab
                ? UsageQueryService.shared.localError
                : UsageQueryService.shared.remoteError
            if let error {
                testState.wrappedValue = .failed(error)
            } else {
                testState.wrappedValue = .success
            }
        }
    }

    // — Local config
    private var configLocal: some View {
        VStack(spacing: 14) {
            icon("house.fill", color: .blue)
            Text(L10n.s("onboard.localMode")).font(.system(size: 20, weight: .bold))
            Text("\(L10n.s("onboard.localCrab"))\n\(L10n.s("onboard.localCrawfish"))")
                .font(.system(size: 12)).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 40)

            VStack(spacing: 8) {
                infoRow("checkmark.circle.fill", .green, L10n.s("onboard.foundClaude"), "~/.claude/")
                infoRow("bolt.fill", .orange, L10n.s("onboard.autoInstall"), "hooks/")
                infoRow("network", .blue, L10n.s("onboard.localComm"), L10n.s("onboard.unixSocket"))
                if remoteEnabled {
                    infoRow("antenna.radiowaves.left.and.right", .cyan, L10n.s("onboard.remoteConn"), L10n.s("onboard.gatewayWS"))
                }
            }.padding(.horizontal, 32)
        }
    }

    // — Monitor config
    private var configMonitor: some View {
        VStack(spacing: 14) {
            icon("display", color: .blue)
            Text(L10n.s("onboard.monitorMode")).font(.system(size: 20, weight: .bold))
            Text(L10n.s("onboard.monitorCodeHint"))
                .font(.system(size: 12)).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 40)

            // Pairing code input
            VStack(spacing: 6) {
                TextField(L10n.s("onboard.enterCode"), text: $pairingInput)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                    .onChange(of: pairingInput) { _, newValue in
                        pairingError = nil
                        pairingInput = newValue
                            .replacingOccurrences(of: "-", with: "")
                            .replacingOccurrences(of: " ", with: "")
                    }

                if let ip = decodedIP {
                    Label("\(L10n.s("onboard.hostSide")): \(ip)", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.green)
                } else if let error = pairingError {
                    Label(error, systemImage: "xmark.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
            }

            infoRow("antenna.radiowaves.left.and.right", .blue, L10n.s("settings.localIP"), setup.localIPAddress)
                .padding(.horizontal, 32)

            Text(L10n.s("onboard.listeningTCP").replacingOccurrences(of: "{port}", with: "\(SocketServer.tcpPort)"))
                .font(.system(size: 11)).foregroundColor(.secondary)
        }
    }

    // — Host config
    private var configHost: some View {
        VStack(spacing: 14) {
            icon("leaf.fill", color: .blue)
            Text(L10n.s("onboard.hostMode")).font(.system(size: 20, weight: .bold))
            Text(L10n.s("onboard.hostCodeHint"))
                .font(.system(size: 12)).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 40)

            if setup.isRockpileDetected {
                infoRow("checkmark.circle.fill", .green, L10n.s("onboard.foundRockpile"), "~/.rockpile/")
                    .padding(.horizontal, 32)
            } else {
                infoRow("exclamationmark.triangle", .orange, L10n.s("onboard.notFoundRockpile"), L10n.s("onboard.needInstall"))
                    .padding(.horizontal, 32)
            }

            // Pairing code display
            HStack(spacing: 3) {
                ForEach(Array(setup.pairingCode.enumerated()), id: \.offset) { _, ch in
                    Text(String(ch))
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(.accentColor)
                        .frame(width: 28, height: 38)
                        .background(Color.accentColor.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
            }
            .padding(.vertical, 4)

            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(setup.pairingCode, forType: .string)
                showCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showCopied = false }
            }) {
                Label(showCopied ? L10n.s("onboard.copied") : L10n.s("onboard.copyCode"),
                      systemImage: showCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)

            infoRow("network", .blue, L10n.s("settings.localIP"), setup.localIPAddress)
                .padding(.horizontal, 32)
        }
    }

    private var decodedIP: String? {
        SetupManager.codeToIP(pairingInput)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 步骤 3: 安装 + 测试（合并）
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var installAndTestView: some View {
        VStack(spacing: 16) {
            Spacer()

            switch installPhase {
            case .installing:
                ProgressView().scaleEffect(1.5)
                Text(L10n.s("onboard.installing")).font(.system(size: 16, weight: .medium))

            case .installFailed:
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 44)).foregroundColor(.red)
                Text(L10n.s("onboard.installError")).font(.system(size: 20, weight: .bold))
                Text(L10n.s("onboard.checkPermission"))
                    .font(.system(size: 12)).foregroundColor(.secondary)

            case .testing:
                ProgressView().scaleEffect(1.5)
                Text(L10n.s("onboard.testingConn")).font(.system(size: 16, weight: .medium))

            case .testSuccess:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48)).foregroundColor(.green)
                Text(L10n.s("onboard.allReady")).font(.system(size: 22, weight: .bold))

                if selectedRole == .host {
                    Text(L10n.s("onboard.hostReady"))
                        .font(.system(size: 13)).foregroundColor(.secondary)
                } else {
                    Text(L10n.s("onboard.goFind"))
                        .font(.system(size: 13)).foregroundColor(.secondary)
                }

                if selectedRole != .host {
                    VStack(spacing: 8) {
                        infoRow("folder", .blue, L10n.s("onboard.pluginPath"), "~/.rockpile/plugins/rockpile/")
                        if selectedRole == .host, let ip = decodedIP {
                            infoRow("paperplane", .blue, L10n.s("onboard.eventTarget"), "\(ip):18790")
                        }
                    }.padding(.horizontal, 32)
                }

            case .testFailed(let err):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48)).foregroundColor(.orange)
                Text(L10n.s("onboard.connTestFailed"))
                    .font(.system(size: 16, weight: .bold))
                Text(err).font(.system(size: 12)).foregroundColor(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 32)
                Text(L10n.s("onboard.skipHint"))
                    .font(.system(size: 11)).foregroundColor(.secondary)

            case .monitorWaiting:
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 44)).foregroundColor(.blue)
                Text(L10n.s("onboard.waitingTank")).font(.system(size: 20, weight: .bold))
                Text(L10n.s("onboard.waitingTankDesc"))
                    .font(.system(size: 12)).foregroundColor(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 40)
                Text("\(L10n.s("onboard.pairingCode")): \(setup.pairingCode)")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.accentColor)
            }

            Spacer()

            // Bottom buttons
            HStack {
                if installPhase.isTestFailed {
                    Button(L10n.s("onboard.retry")) {
                        Task {
                            installPhase = .testing
                            let h = selectedRole == .local ? "localhost" : setup.localIPAddress
                            await setup.testConnection(host: h)
                            if case .success = setup.connectionTestResult {
                                installPhase = .testSuccess
                            } else if case .failed(let e) = setup.connectionTestResult {
                                installPhase = .testFailed(e)
                            }
                        }
                    }.buttonStyle(.bordered)
                }

                if installPhase == .installFailed {
                    Button(L10n.s("onboard.retryInstall")) {
                        performInstall()
                    }.buttonStyle(.bordered)
                }

                Spacer()

                switch installPhase {
                case .installing, .testing:
                    EmptyView()
                case .testSuccess:
                    Button(L10n.s("onboard.start")) {
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                case .monitorWaiting:
                    Button(L10n.s("onboard.done")) {
                        finishSetup()
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                default:
                    Button(L10n.s("onboard.skip")) {
                        finishSetup()
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                }
            }
            .padding(.horizontal, 24).padding(.bottom, 20)
        }
    }

    @State private var installPhase: InstallPhase = .installing

    enum InstallPhase: Equatable {
        case installing
        case installFailed
        case testing
        case testSuccess
        case testFailed(String)
        case monitorWaiting

        var isTestFailed: Bool {
            if case .testFailed = self { return true }
            return false
        }
    }

    // MARK: - Actions

    private func performInstall() {
        guard let role = selectedRole else { return }

        // Save dual O₂ settings (v2.0)
        AppSettings.localOxygenMode = localO2Mode
        AppSettings.localOxygenTankCapacity = localTankCapacity
        AppSettings.remoteOxygenMode = remoteO2Mode
        AppSettings.remoteOxygenTankCapacity = remoteTankCapacity
        AppSettings.remoteEnabled = remoteEnabled

        // Backward compat: also write legacy keys
        AppSettings.oxygenMode = localO2Mode
        AppSettings.oxygenTankCapacity = localTankCapacity

        // Save Usage API settings (v2.1)
        AppSettings.localProvider = localProvider
        AppSettings.remoteProvider = remoteProvider
        if !localAdminKey.isEmpty, let p = AIProvider(rawValue: localProvider) {
            AdminKeyManager.storeKey(for: p, creature: .hermitCrab, key: localAdminKey)
            AppSettings.localUsageAPIEnabled = true
            if p.needsTeamId { AdminKeyManager.storeTeamId(localTeamId, creature: .hermitCrab) }
        }
        if !remoteAdminKey.isEmpty, let p = AIProvider(rawValue: remoteProvider) {
            AdminKeyManager.storeKey(for: p, creature: .crawfish, key: remoteAdminKey)
            AppSettings.remoteUsageAPIEnabled = true
            if p.needsTeamId { AdminKeyManager.storeTeamId(remoteTeamId, creature: .crawfish) }
        }

        step = .installAndTest
        installPhase = .installing

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))

            switch role {
            case .local:
                let ok = setup.installPluginLocal()
                if !ok {
                    installPhase = .installFailed
                    return
                }
                // Test connection
                installPhase = .testing
                await setup.testConnection(host: "localhost")
                finishSetup()
                if case .success = setup.connectionTestResult {
                    installPhase = .testSuccess
                } else if case .failed(let err) = setup.connectionTestResult {
                    installPhase = .testFailed(err)
                } else {
                    installPhase = .testSuccess
                }

            case .monitor:
                guard let serverIP = decodedIP else {
                    pairingError = L10n.s("onboard.badCode")
                    step = .configAndO2
                    return
                }
                installPhase = .testing
                AppSettings.rockpileHost = serverIP
                let registered = await setup.registerWithServer(serverIP: serverIP)
                finishSetup()
                if registered {
                    installPhase = .testSuccess
                } else {
                    installPhase = .testFailed(L10n.s("onboard.cantConnect") + " \(serverIP)")
                }

            case .host:
                finishSetup()
                installPhase = .monitorWaiting
            }
        }
    }

    private func finishSetup() {
        guard let role = selectedRole else { return }
        AppSettings.setupRole = role.rawValue
        AppSettings.connectionMode = "plugin"
        AppSettings.setupCompleted = true
    }

    // MARK: - Reusable Components

    private func roleCard(_ role: Role, icon: String, title: String, desc: String, disabled: Bool = false) -> some View {
        let selected = selectedRole == role
        return Button {
            if !disabled { selectedRole = role }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(selected ? .white : .accentColor)
                    .frame(width: 34, height: 34)
                    .background(selected ? Color.accentColor : Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Text(desc).font(.system(size: 11)).foregroundColor(.secondary)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(selected ? Color.accentColor.opacity(0.06) : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .stroke(selected ? Color.accentColor : Color.gray.opacity(0.2),
                        lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .opacity(disabled ? 0.4 : 1)
    }

    private func icon(_ name: String, color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 36))
            .foregroundColor(color)
    }

    private func infoRow(_ icon: String, _ color: Color, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(color)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 11, weight: .medium))
                Text(detail).font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    private func navButtons(back: (() -> Void)?, action: @escaping () -> Void) -> some View {
        HStack {
            if let back = back {
                Button(L10n.s("onboard.back")) { back() }.buttonStyle(.bordered)
            }
            Spacer()
            Button(L10n.s("onboard.next")) { action() }
                .buttonStyle(.borderedProminent).controlSize(.large)
        }
        .padding(.horizontal, 24).padding(.bottom, 20)
    }

    private func o2ModeButton(_ label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .font(.system(size: 12))
            .buttonStyle(.plain)
            .foregroundColor(isActive ? .white : .primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? Color.accentColor : Color.gray.opacity(0.12))
            )
    }

    private func settingSummaryRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
        }
    }

    private func roleName(_ role: String) -> String {
        AppSettings.roleName(role)
    }
}
