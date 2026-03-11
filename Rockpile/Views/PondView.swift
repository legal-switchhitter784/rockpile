import SwiftUI

// MARK: - Underwater Scene (SpongeBob-inspired)

struct PondView: View {
    let sessions: [SessionData]
    var selectedSessionId: String?
    /// Oxygen level from the effective session's TokenTracker (1.0 = full, 0.0 = depleted)
    var oxygenLevel: Double = 1.0
    /// Token trackers for default (idle) creatures when no active session
    var localTokenTracker: TokenTracker?
    var remoteTokenTracker: TokenTracker?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Deep ocean gradient — darkens and turns murky when oxygen is low
                LinearGradient(
                    colors: waterGradientColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                // 🏖️ Sandy ocean floor (SpongeBob-style ground for creature contrast)
                OceanFloorView(width: geometry.size.width, height: geometry.size.height)

                // Seaweed clusters (rendered ON TOP of sand)
                SeaweedCluster(in: geometry.size)
                    .allowsHitTesting(false)

                // Floating bubbles — fewer when oxygen is low
                BubblesView(in: geometry.size, oxygenLevel: oxygenLevel)
                    .allowsHitTesting(false)

                // 🪨 Bottom decorations (stones + clickable shell, sitting on sand)
                DecorationView(width: geometry.size.width, height: geometry.size.height, groundHeight: OceanFloorView.groundHeight)

                // Murky overlay when oxygen is critically low
                if oxygenLevel < 0.3 {
                    Color(red: 0.05, green: 0.10, blue: 0.02)
                        .opacity(murkyOverlayOpacity)
                        .allowsHitTesting(false)
                }

                // Render sprites — always show both creature types
                ZStack(alignment: .bottom) {
                    Color.clear
                        .allowsHitTesting(false)

                    let crawfish = sessions.filter { $0.creatureType == .crawfish }
                    let crabs = sessions.filter { $0.creatureType == .hermitCrab }

                    // 🦞 Crawfish: mid-water level (30% 池塘需要更高位置)
                    if crawfish.isEmpty {
                        // Default idle crawfish (always visible, swims above sand)
                        UnderwaterSpriteView(
                            state: .sleeping,
                            xPosition: 0.75,
                            yOffset: -45,
                            totalWidth: geometry.size.width,
                            glowOpacity: 0,
                            isDead: remoteTokenTracker?.isDead ?? false,
                            tokenTracker: remoteTokenTracker
                        )
                    } else if crawfish.count == 1, let session = crawfish.first {
                        UnderwaterSpriteView(
                            state: session.state,
                            xPosition: crabs.isEmpty ? 0.5 : session.spriteXPosition,
                            yOffset: crabs.isEmpty ? -38 : max(-60, session.spriteYOffset - 20),
                            totalWidth: geometry.size.width,
                            glowOpacity: glowOpacity(for: session.id),
                            isDead: session.tokenTracker.isDead,
                            tokenTracker: session.tokenTracker
                        )
                    } else {
                        ForEach(depthSorted(crawfish)) { session in
                            UnderwaterSpriteView(
                                state: session.state,
                                xPosition: session.spriteXPosition,
                                yOffset: max(-60, session.spriteYOffset - 20),
                                totalWidth: geometry.size.width,
                                glowOpacity: glowOpacity(for: session.id),
                                isDead: session.tokenTracker.isDead,
                                tokenTracker: session.tokenTracker
                            )
                        }
                    }

                    // 🐚 Hermit crabs: lower-mid level (30% 池塘需要更高位置)
                    if crabs.isEmpty {
                        // Default idle hermit crab (always visible, sits ON sand)
                        GroundSpriteView(
                            state: .sleeping,
                            xPosition: 0.25,
                            yOffset: -30,
                            totalWidth: geometry.size.width,
                            glowOpacity: 0,
                            isDead: localTokenTracker?.isDead ?? false,
                            tokenTracker: localTokenTracker
                        )
                    } else if crabs.count == 1, let session = crabs.first {
                        GroundSpriteView(
                            state: session.state,
                            xPosition: crawfish.isEmpty ? 0.5 : session.spriteXPosition,
                            yOffset: crawfish.isEmpty ? -28 : max(-40, session.spriteYOffset - 10),
                            totalWidth: geometry.size.width,
                            glowOpacity: glowOpacity(for: session.id),
                            isDead: session.tokenTracker.isDead,
                            tokenTracker: session.tokenTracker
                        )
                    } else {
                        ForEach(crabs) { session in
                            GroundSpriteView(
                                state: session.state,
                                xPosition: session.spriteXPosition,
                                yOffset: max(-40, session.spriteYOffset - 10),
                                totalWidth: geometry.size.width,
                                glowOpacity: glowOpacity(for: session.id),
                                isDead: session.tokenTracker.isDead,
                                tokenTracker: session.tokenTracker
                            )
                        }
                    }
                }

                // ✨ Cross-creature interaction FX (between sprites and surface)
                InteractionFXView(
                    fxTrigger: InteractionCoordinator.shared.fxTrigger,
                    meetingX: InteractionCoordinator.shared.meetingX,
                    totalWidth: geometry.size.width,
                    interactionType: currentInteractionType
                )

                // 🌊 Water surface waves at top
                VStack {
                    WaterSurfaceView(width: geometry.size.width, oxygenLevel: oxygenLevel)
                    Spacer()
                }
                .allowsHitTesting(false)
            }
        }
    }

    /// Extract interaction type from coordinator phase
    private var currentInteractionType: InteractionCoordinator.InteractionType? {
        switch InteractionCoordinator.shared.phase {
        case .interacting(let type): return type
        case .approaching(let type): return type
        default: return nil
        }
    }

    // MARK: - Oxygen-Dependent Visuals

    /// Water gradient shifts from clear blue to dark murky green as oxygen drops
    private var waterGradientColors: [Color] {
        if oxygenLevel > 0.6 {
            // Normal: clear blue ocean
            return [
                Color(red: 0.02, green: 0.08, blue: 0.18),
                Color(red: 0.04, green: 0.14, blue: 0.30),
                Color(red: 0.06, green: 0.20, blue: 0.38),
                Color(red: 0.08, green: 0.25, blue: 0.42),
            ]
        } else if oxygenLevel > 0.3 {
            // Warning: slightly darker, greenish tint
            let mix = (0.6 - oxygenLevel) / 0.3 // 0→1 as oxygen drops 0.6→0.3
            return [
                Color(red: 0.02, green: 0.08 + mix * 0.02, blue: 0.18 - mix * 0.04),
                Color(red: 0.04, green: 0.14 + mix * 0.03, blue: 0.28 - mix * 0.06),
                Color(red: 0.05, green: 0.18 + mix * 0.04, blue: 0.32 - mix * 0.08),
                Color(red: 0.06, green: 0.22 + mix * 0.04, blue: 0.35 - mix * 0.10),
            ]
        } else {
            // Critical: dark murky water
            return [
                Color(red: 0.02, green: 0.06, blue: 0.08),
                Color(red: 0.03, green: 0.10, blue: 0.12),
                Color(red: 0.04, green: 0.14, blue: 0.14),
                Color(red: 0.05, green: 0.16, blue: 0.15),
            ]
        }
    }

    /// Murky green overlay opacity (only active below 30%)
    private var murkyOverlayOpacity: Double {
        let severity = (0.3 - oxygenLevel) / 0.3 // 0→1 as oxygen drops 0.3→0.0
        return severity * 0.25
    }

    private func depthSorted(_ sessions: [SessionData]) -> [SessionData] {
        sessions.sorted { $0.spriteYOffset < $1.spriteYOffset }
    }

    private func glowOpacity(for id: String) -> Double {
        if id == selectedSessionId { return 0.6 }
        return 0.15
    }
}

// MARK: - Ocean Floor (SpongeBob-style)

/// 海绵宝宝风格海底沙地 — 暖色沙地 + 纹理 + 小石子
/// 提供视觉对比，让寄居蟹在沙地上清晰可见
private struct OceanFloorView: View {
    let width: CGFloat
    let height: CGFloat

    /// 地面高度 (从底部算起) — 增大以提供更明显的海底对比
    static let groundHeight: CGFloat = 30

    var body: some View {
        Canvas { context, size in
            let gh = Self.groundHeight
            let groundTop = size.height - gh

            // ── 1. Main sand body with undulating surface ──
            var sandPath = Path()
            sandPath.move(to: CGPoint(x: 0, y: size.height))
            sandPath.addLine(to: CGPoint(x: 0, y: groundTop + Self.hillY(at: 0)))

            let segments = 24
            for i in 1...segments {
                let x = CGFloat(i) / CGFloat(segments) * size.width
                let y = groundTop + Self.hillY(at: CGFloat(i))
                sandPath.addLine(to: CGPoint(x: x, y: y))
            }
            sandPath.addLine(to: CGPoint(x: size.width, y: size.height))
            sandPath.closeSubpath()

            // Warm tan gradient fill
            context.fill(sandPath, with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.82, green: 0.68, blue: 0.48),  // Light warm sand
                    Color(red: 0.72, green: 0.58, blue: 0.40),  // Mid sand
                    Color(red: 0.58, green: 0.44, blue: 0.30),  // Darker base
                ]),
                startPoint: CGPoint(x: size.width / 2, y: groundTop),
                endPoint: CGPoint(x: size.width / 2, y: size.height)
            ))

            // ── 2. Surface highlight line (top edge of sand) ──
            var edgePath = Path()
            edgePath.move(to: CGPoint(x: 0, y: groundTop + Self.hillY(at: 0)))
            for i in 1...segments {
                let x = CGFloat(i) / CGFloat(segments) * size.width
                let y = groundTop + Self.hillY(at: CGFloat(i))
                edgePath.addLine(to: CGPoint(x: x, y: y))
            }
            context.stroke(edgePath, with: .color(
                Color(red: 0.90, green: 0.78, blue: 0.58).opacity(0.7)
            ), lineWidth: 1.5)

            // ── 3. Sand texture specks (deterministic positions) ──
            for i in 0..<30 {
                let fx = fmod(CGFloat(i) * 14.7 + 3.2, size.width)
                let fy = groundTop + 5 + fmod(CGFloat(i) * 4.3 + 1.1, gh - 6)
                let ds: CGFloat = CGFloat(i % 3 + 1) * 0.6
                context.fill(
                    Path(CGRect(x: fx, y: fy, width: ds, height: ds)),
                    with: .color(Color(red: 0.50, green: 0.38, blue: 0.26).opacity(0.3))
                )
            }

            // ── 4. Lighter sand patches near surface ──
            for i in 0..<12 {
                let fx = fmod(CGFloat(i) * 38.5 + 10.3, size.width)
                let fy = groundTop + Self.hillY(at: CGFloat(i) * 2) + 3
                let pw: CGFloat = CGFloat(i % 3 + 3) * 1.5
                let ph: CGFloat = pw * 0.4
                context.fill(
                    Path(ellipseIn: CGRect(x: fx - pw / 2, y: fy, width: pw, height: ph)),
                    with: .color(Color(red: 0.90, green: 0.78, blue: 0.60).opacity(0.35))
                )
            }

            // ── 5. Small embedded pebbles ──
            let pebbles: [(x: CGFloat, yF: CGFloat, w: CGFloat, h: CGFloat, dark: Bool)] = [
                (0.08, 0.40, 3.5, 2.0, true),
                (0.25, 0.55, 2.5, 1.8, false),
                (0.38, 0.35, 4.0, 2.5, true),
                (0.55, 0.50, 3.0, 2.0, false),
                (0.72, 0.38, 3.5, 2.2, true),
                (0.88, 0.45, 2.8, 1.8, false),
            ]
            for p in pebbles {
                let px = size.width * p.x
                let py = groundTop + gh * p.yF
                let r = CGRect(x: px - p.w / 2, y: py, width: p.w, height: p.h)
                let color = p.dark
                    ? Color(red: 0.40, green: 0.32, blue: 0.22)
                    : Color(red: 0.55, green: 0.45, blue: 0.32)
                context.fill(Path(ellipseIn: r), with: .color(color.opacity(0.5)))
            }
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
    }

    /// Deterministic hill profile for undulating sand surface
    private static func hillY(at i: CGFloat) -> CGFloat {
        let a = sin(Double(i) * 0.5 + 0.3) * 2.5
        let b = sin(Double(i) * 1.1 + 1.8) * 1.2
        return CGFloat(a + b)
    }
}

// MARK: - Seaweed

private struct SeaweedCluster: View {
    let size: CGSize

    init(in size: CGSize) {
        self.size = size
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Left seaweed cluster (缩小适配 30% 池塘)
            SeaweedStalk(height: 25, sway: 2)
                .offset(x: -size.width * 0.38, y: 0)
            SeaweedStalk(height: 18, sway: 1.5)
                .offset(x: -size.width * 0.35, y: 0)

            // Right seaweed cluster
            SeaweedStalk(height: 28, sway: 2.5)
                .offset(x: size.width * 0.35, y: 0)
            SeaweedStalk(height: 20, sway: 1.5)
                .offset(x: size.width * 0.38, y: 0)

            // Far left single
            SeaweedStalk(height: 15, sway: 1)
                .offset(x: -size.width * 0.45, y: 0)
                .opacity(0.6)

            // Far right single
            SeaweedStalk(height: 17, sway: 1.2)
                .offset(x: size.width * 0.44, y: 0)
                .opacity(0.6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}

private struct SeaweedStalk: View {
    let height: CGFloat
    let sway: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15, paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            let swayOffset = sin(t * 0.8) * sway

            Canvas { context, canvasSize in
                var path = Path()
                let baseX = canvasSize.width / 2
                let baseY = canvasSize.height
                let segments = 6

                path.move(to: CGPoint(x: baseX, y: baseY))

                for i in 1...segments {
                    let frac = CGFloat(i) / CGFloat(segments)
                    let x = baseX + sin(frac * .pi * 1.2) * sway + swayOffset * frac
                    let y = baseY - height * frac
                    let cpX = baseX + sin((frac - 0.08) * .pi * 1.2) * sway * 0.8
                    let cpY = baseY - height * (frac - 0.05)
                    path.addQuadCurve(to: CGPoint(x: x, y: y),
                                      control: CGPoint(x: cpX, y: cpY))
                }

                context.stroke(
                    path,
                    with: .color(Color(red: 0.1, green: 0.45, blue: 0.2).opacity(0.7)),
                    lineWidth: 3
                )
                // Draw leaf blobs
                for i in stride(from: 2, through: segments, by: 2) {
                    let frac = CGFloat(i) / CGFloat(segments)
                    let x = baseX + sin(frac * .pi * 1.2) * sway + swayOffset * frac
                    let y = baseY - height * frac

                    let leafRect = CGRect(x: x - 5, y: y - 3, width: 10, height: 6)
                    context.fill(
                        Path(ellipseIn: leafRect),
                        with: .color(Color(red: 0.12, green: 0.5, blue: 0.25).opacity(0.6))
                    )
                }
            }
            .frame(width: 30, height: height + 10)
        }
    }
}

// MARK: - Bubbles

private struct BubblesView: View {
    let size: CGSize
    let oxygenLevel: Double

    init(in size: CGSize, oxygenLevel: Double = 1.0) {
        self.size = size
        self.oxygenLevel = oxygenLevel
    }

    // Fixed bubble positions (seeded, not random each frame)
    private let allBubbles: [(x: CGFloat, speed: Double, bubbleSize: CGFloat, phase: Double)] = [
        (0.15, 12, 3, 0.0),
        (0.30, 16, 2, 2.1),
        (0.45, 10, 4, 4.5),
        (0.60, 14, 2.5, 1.3),
        (0.75, 18, 3, 3.7),
        (0.85, 11, 2, 5.2),
        (0.20, 15, 3.5, 6.0),
        (0.55, 13, 2, 0.8),
    ]

    /// Number of visible bubbles based on oxygen level
    private var visibleBubbleCount: Int {
        if oxygenLevel <= 0 { return 0 }          // Dead: no bubbles at all
        if oxygenLevel < 0.1 { return 1 }          // Near-death: 1 slow bubble
        return max(1, Int(Double(allBubbles.count) * oxygenLevel))
    }

    /// Bubble speed multiplier — slower when oxygen is low
    private var speedMultiplier: Double {
        if oxygenLevel <= 0 { return 0 }
        return max(0.3, oxygenLevel)
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 10, paused: reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, canvasSize in
                guard !reduceMotion else { return } // Hide decorative bubbles
                let bubbles = Array(allBubbles.prefix(visibleBubbleCount))
                for bubble in bubbles {
                    let adjustedSpeed = bubble.speed / speedMultiplier
                    let cycleTime = adjustedSpeed
                    let progress = ((t + bubble.phase).truncatingRemainder(dividingBy: cycleTime)) / cycleTime
                    let x = canvasSize.width * bubble.x + sin(t * 0.5 + bubble.phase) * 4
                    let y = canvasSize.height * (1.0 - progress)

                    // Bubbles become more transparent when oxygen is low
                    let alphaScale = max(0.4, oxygenLevel)

                    let rect = CGRect(
                        x: x - bubble.bubbleSize,
                        y: y - bubble.bubbleSize,
                        width: bubble.bubbleSize * 2,
                        height: bubble.bubbleSize * 2
                    )

                    // Bubble outline
                    context.stroke(
                        Path(ellipseIn: rect),
                        with: .color(Color(red: 0.5, green: 0.75, blue: 0.95).opacity(0.35 * alphaScale)),
                        lineWidth: 0.8
                    )
                    // Bubble highlight
                    let highlightRect = CGRect(
                        x: x - bubble.bubbleSize * 0.3,
                        y: y - bubble.bubbleSize * 0.5,
                        width: bubble.bubbleSize * 0.6,
                        height: bubble.bubbleSize * 0.4
                    )
                    context.fill(
                        Path(ellipseIn: highlightRect),
                        with: .color(Color.white.opacity(0.15 * alphaScale))
                    )
                }
            }
        }
    }
}

// MARK: - Breath Bubbles (linked to sprite)

/// 龙虾嘴部冒出的小气泡 — 频率随状态变化
private struct BreathBubblesView: View {
    let isDead: Bool
    let task: ClawTask
    let spriteSize: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Bubble cycle time based on task activity
    private var cycleBase: Double {
        if isDead { return 100 } // Effectively invisible
        switch task {
        case .working:    return 2.0
        case .thinking:   return 2.8
        case .idle:       return 4.0
        case .compacting: return 2.5
        case .sleeping:   return 6.0
        case .waiting:    return 4.5
        case .error:      return 3.5
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 10, paused: isDead || reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                guard !isDead, !reduceMotion else { return }
                // Mouth area: slightly right and above center of sprite
                let mouthX = size.width / 2 + 6
                let mouthY = size.height / 2 - 4

                // 3 tiny bubbles rising from mouth
                for i in 0..<3 {
                    let phase = Double(i) * 1.3
                    let cycle = cycleBase + Double(i) * 0.6
                    let progress = ((t + phase).truncatingRemainder(dividingBy: cycle)) / cycle

                    let x = mouthX + CGFloat(sin(t * 0.7 + phase) * 2.5)
                    let y = mouthY - CGFloat(progress) * spriteSize * 0.4

                    // Deterministic size based on index
                    let bSize: CGFloat = 1.5 + CGFloat(i) * 0.4
                    let alpha = (1.0 - progress) * 0.45

                    let rect = CGRect(
                        x: x - bSize / 2, y: y - bSize / 2,
                        width: bSize, height: bSize
                    )
                    context.stroke(
                        Path(ellipseIn: rect),
                        with: .color(Color(red: 0.5, green: 0.78, blue: 0.95).opacity(alpha)),
                        lineWidth: 0.5
                    )
                }
            }
        }
        .frame(width: spriteSize, height: spriteSize)
        .allowsHitTesting(false)
    }
}

// MARK: - Heart Particles (double-tap reaction)

/// 双击龙虾时的心形粒子效果
private struct HeartParticlesView: View {
    let triggerCounter: Int
    let size: CGFloat

    @State private var hearts: [HeartParticle] = []
    @State private var startTime: Double = 0

    private struct HeartParticle: Identifiable {
        let id = UUID()
        let startX: CGFloat
        let xDrift: CGFloat
        let speed: Double
        let scale: CGFloat
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15, paused: hearts.isEmpty)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate - startTime
            ZStack {
                ForEach(hearts) { heart in
                    let progress = min(1.0, elapsed * heart.speed)
                    Text("\u{2764}\u{FE0F}")
                        .font(.system(size: 8 * heart.scale))
                        .offset(
                            x: heart.startX + sin(elapsed * 2 + Double(heart.xDrift)) * 5,
                            y: -CGFloat(progress) * size * 0.5
                        )
                        .opacity(max(0, 1.0 - progress))
                }
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
        .onChange(of: triggerCounter) { _, _ in
            spawnHearts()
        }
    }

    private func spawnHearts() {
        let count = Int.random(in: 3...5)
        var newHearts: [HeartParticle] = []
        for _ in 0..<count {
            newHearts.append(HeartParticle(
                startX: CGFloat.random(in: -15...15),
                xDrift: CGFloat.random(in: -3...3),
                speed: Double.random(in: 0.5...0.9),
                scale: CGFloat.random(in: 0.8...1.3)
            ))
        }
        hearts = newHearts
        startTime = Date.timeIntervalSinceReferenceDate

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            hearts = []
        }
    }
}

// MARK: - Underwater Sprite (Interactive)

private struct UnderwaterSpriteView: View {
    let state: ClawState
    let xPosition: CGFloat
    let yOffset: CGFloat
    let totalWidth: CGFloat
    let glowOpacity: Double
    var isDead: Bool = false
    var tokenTracker: TokenTracker?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let spriteSize: CGFloat = 80
    private static let usableWidthFraction: CGFloat = 0.8
    private static let leftMarginFraction: CGFloat = 0.1

    // ── Swimming ──
    @State private var swimOffset: CGFloat = 0
    @State private var facingLeft: Bool = false
    @State private var canSwim: Bool = false

    // ── Entry animation ──
    @State private var entryScale: CGFloat = 0.3
    @State private var showSplash: Bool = false

    // ── State transition ──
    @State private var transitionScale: CGFloat = 1.0
    @State private var transitionCounter: Int = 0

    // ── Interaction: tap reaction ──
    @State private var jumpOffset: CGFloat = 0
    @State private var tapCooldown: Bool = false
    @State private var reactionText: String? = nil
    @State private var reactionOpacity: Double = 0

    // ── Interaction: triple-tap punishment ──
    @State private var recentTapTimes: [Date] = []
    @State private var isAngry: Bool = false

    // ── Interaction: drag ──
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false

    // ── Interaction: double-tap hearts ──
    @State private var heartCounter: Int = 0

    // ── Interaction: long-press info card ──
    @State private var showInfoCard: Bool = false
    @State private var infoCardDismissId: UUID = UUID()

    // ── Interaction: feeding ──
    @State private var feedCounter: Int = 0
    @State private var feedReactionScale: CGFloat = 1.0

    // ── Cross-creature interaction (互动) ──
    @State private var interactionOffset: CGSize = .zero

    // ── 点击唤醒 ──
    @State private var manuallyAwake: Bool = false

    private var xOffset: CGFloat {
        let usableWidth = totalWidth * Self.usableWidthFraction
        let leftMargin = totalWidth * Self.leftMarginFraction
        return leftMargin + (xPosition * usableWidth) - (totalWidth / 2)
    }

    private var stateColor: Color { state.task.statusColor }

    var body: some View {
        ZStack {
            // 💀 Ghost effect — floats up on death
            GhostSpriteView(state: state, size: Self.spriteSize, isDead: isDead)
                .allowsHitTesting(false)

            // 🫧 Breath bubbles from mouth
            BreathBubblesView(isDead: isDead, task: state.task, spriteSize: Self.spriteSize)

            // Main sprite container with all overlays
            ZStack {
                // 🦞 Core sprite
                CrawfishSpriteView(
                    state: state,
                    isSelected: glowOpacity > 0.3,
                    size: Self.spriteSize,
                    isDead: isDead
                )

                // ✨ Transition star particles
                TransitionFXView(
                    triggerCounter: transitionCounter,
                    stateColor: stateColor,
                    size: Self.spriteSize
                )
            }
            .scaleEffect(entryScale * transitionScale * feedReactionScale)
            .scaleEffect(x: facingLeft ? -1 : 1, y: 1)
            // ── Hit area: frame + contentShape on sprite core ──
            .frame(width: Self.spriteSize, height: Self.spriteSize)
            .contentShape(Rectangle())
            // ── Gestures: drag (min distance avoids tap conflict) ──
            .highPriorityGesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            canSwim = false
                            InteractionCoordinator.shared.cancelInteraction()
                        }
                        dragOffset = value.translation
                    }
                    .onEnded { _ in
                        isDragging = false
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                            dragOffset = .zero
                        }
                        // Resume swimming after snap-back
                        if (state.task.canWalk || manuallyAwake) && !isDead && !reduceMotion {
                            canSwim = true
                            scheduleSwim()
                        }
                        updateInteractionEligibility()
                    }
            )
            // ── Tap gestures: double-tap first, then single-tap ──
            .onTapGesture(count: 2) {
                handleDoubleTap()
            }
            .onTapGesture(count: 1) {
                handleSingleTap()
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                handleLongPress()
            }
            // ── Context menu for feeding ──
            .contextMenu {
                if let tracker = tokenTracker {
                    Button {
                        handleFeed(tracker: tracker)
                    } label: {
                        if tracker.isOverfed {
                            Label(L10n.s("feed.overfed"), systemImage: "face.dashed")
                        } else if tracker.canFeed {
                            Label(L10n.s("feed.feed"), systemImage: "fork.knife")
                        } else {
                            let remaining = Int(tracker.feedCooldownRemaining)
                            Label("\(L10n.s("feed.cooldown")) \(remaining)s", systemImage: "clock")
                        }
                    }
                    .disabled(!tracker.canFeed)
                } else {
                    Button {} label: {
                        Label(L10n.s("sprite.noSession"), systemImage: "zzz")
                    }
                    .disabled(true)
                }
            }
            .accessibilityLabel("\(L10n.s("sprite.accessCrawfish")), \(state.displayName)")
            .accessibilityHint(L10n.s("sprite.accessHint"))

            // ❤️ Heart particles (double-tap)
            HeartParticlesView(triggerCounter: heartCounter, size: Self.spriteSize)

            // 🫧 Bubble dialog above sprite
            PixelBubbleView(task: state.task, isDead: isDead, spriteSize: Self.spriteSize)
                .allowsHitTesting(false)

            // 💬 Reaction text (tap feedback)
            if let reaction = reactionText {
                Text(reaction)
                    .font(DS.Font.monoBold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.orange.opacity(0.85))
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                            )
                    )
                    .offset(y: -Self.spriteSize * 0.65)
                    .opacity(reactionOpacity)
                    .allowsHitTesting(false)
            }

            // 📋 Info card (long-press) — compact tooltip, offset to the right
            SpriteInfoCardView(
                state: state,
                oxygenLevel: tokenTracker?.oxygenLevel ?? 1.0,
                sessionTokens: tokenTracker?.sessionTotalTokens ?? 0,
                isVisible: showInfoCard
            )
            .offset(x: Self.spriteSize * 0.45, y: -Self.spriteSize * 0.3)
            .id(infoCardDismissId)

            // 💦 Entry splash particles
            SplashParticleView(
                isActive: showSplash,
                origin: CGPoint(x: Self.spriteSize, y: Self.spriteSize * 0.6),
                size: Self.spriteSize * 2.5
            )

            // 🍤 Food particles (feeding)
            FoodParticleView(
                triggerCounter: feedCounter,
                targetY: Self.spriteSize * 0.4,
                size: Self.spriteSize * 2
            )
            .offset(y: -Self.spriteSize * 0.3)

            // 📱 Remote activity bubble (展开后从 header 转移到小龙虾)
            ActivityBadgeView(
                bubbleCount: RemoteActivityTracker.shared.bubbleCount,
                isBubbleShowing: RemoteActivityTracker.shared.isBubbleShowing,
                bubbleTrigger: RemoteActivityTracker.shared.bubbleTrigger,
                spriteSize: Self.spriteSize
            )
        }
        .shadow(color: Color(red: 0.3, green: 0.6, blue: 0.8).opacity(glowOpacity * 0.5), radius: 6)
        .offset(x: xOffset + swimOffset + interactionOffset.width + dragOffset.width,
                y: yOffset + jumpOffset + interactionOffset.height + dragOffset.height)
        // ── Lifecycle ──
        .onAppear {
            if reduceMotion {
                entryScale = 1.0
            } else {
                // Entry animation: scale 0.3 → 1.0 with spring
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    entryScale = 1.0
                }
                // Trigger splash particles slightly after entry begins
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    showSplash = true
                }
            }
            // Start swimming if possible (disabled when reduceMotion)
            canSwim = state.task.canWalk && !isDead && !reduceMotion
            if canSwim {
                scheduleSwim()
            }
            // 📱 展开时消费远程活动通知 → 触发小龙虾气泡
            RemoteActivityTracker.shared.consumeForBubble()
            // 互动: 注册可互动状态
            updateInteractionEligibility()
        }
        // ── State change: transition bounce + FX ──
        .onChange(of: state.task) { _, newTask in
            if !reduceMotion {
                // Bounce: 1.0 → 1.15 → 1.0
                withAnimation(.spring(response: 0.15, dampingFraction: 0.3)) {
                    transitionScale = 1.15
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                        transitionScale = 1.0
                    }
                }
                // Trigger star particles
                transitionCounter += 1
            }
            // Update swimming
            canSwim = newTask.canWalk && !isDead && !reduceMotion
            if canSwim {
                scheduleSwim()
            }
            updateInteractionEligibility()
        }
        .onChange(of: isDead) { _, dead in
            canSwim = state.task.canWalk && !dead && !reduceMotion
            updateInteractionEligibility()
        }
        // ── Cross-creature interaction phase observer ──
        .onChange(of: InteractionCoordinator.shared.phase) { _, newPhase in
            handleInteractionPhase(newPhase)
        }
    }

    // MARK: - Swimming Logic

    private func scheduleSwim() {
        let delay = Double.random(in: 8.0...15.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard canSwim else { return }
            performSwim()
        }
    }

    private func performSwim() {
        let maxOffset: CGFloat = 25
        let target = CGFloat.random(in: -maxOffset...maxOffset)
        facingLeft = target < swimOffset

        let duration = Double.random(in: 1.0...2.0)
        withAnimation(.easeInOut(duration: duration)) {
            swimOffset = target
        }

        // Schedule next swim after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.2) {
            guard canSwim else { return }
            scheduleSwim()
        }
    }

    // MARK: - Interaction Handlers

    private func handleSingleTap() {
        guard !tapCooldown, !isDead else { return }
        tapCooldown = true

        // Triple-tap punishment detection
        let now = Date()
        recentTapTimes.append(now)
        recentTapTimes.removeAll { now.timeIntervalSince($0) > 2.0 }

        if recentTapTimes.count >= 3 {
            handlePunishment()
            recentTapTimes.removeAll()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { tapCooldown = false }
            return
        }

        // 点击唤醒: 睡眠状态下点击 → 立即开始游泳 60 秒
        if !canSwim && !isDead && !reduceMotion {
            manuallyAwake = true
            canSwim = true
            performSwim()   // ← 立即移动，不等 8-15 秒
            DispatchQueue.main.asyncAfter(deadline: .now() + 60.0) {
                guard manuallyAwake else { return }
                manuallyAwake = false
                if !state.task.canWalk {
                    canSwim = false
                }
            }
        }

        // Jump reaction — 小龙虾弹跳（外向性格）
        withAnimation(.spring(response: 0.15, dampingFraction: 0.3)) {
            jumpOffset = -12
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
                jumpOffset = 0
            }
        }

        // State-aware reaction text
        showReaction(CreatureReactions.tapReaction(creature: .crawfish, task: state.task, isDead: isDead))

        // Squash-stretch effect
        withAnimation(.spring(response: 0.1, dampingFraction: 0.3)) {
            transitionScale = 1.1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                transitionScale = 1.0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { tapCooldown = false }
    }

    private func handleDoubleTap() {
        guard !isDead else { return }
        heartCounter += 1

        // State-aware love reaction
        showReaction(CreatureReactions.loveReaction(creature: .crawfish, task: state.task, isDead: isDead), duration: 1.5)

        // Bounce
        withAnimation(.spring(response: 0.15, dampingFraction: 0.3)) {
            transitionScale = 1.15
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                transitionScale = 1.0
            }
        }
    }

    private func handleLongPress() {
        guard !isDead else { return }
        showInfoCard = true
        infoCardDismissId = UUID()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { showInfoCard = false }
    }

    private func handleFeed(tracker: TokenTracker) {
        let wasOverfed = tracker.isOverfed
        guard tracker.feed() else {
            // Overfed rejection feedback
            if wasOverfed || tracker.isOverfed {
                showReaction(CreatureReactions.feedReaction(creature: .crawfish, isOverfed: true))
                // Queasy shake
                withAnimation(.spring(response: 0.08, dampingFraction: 0.2)) {
                    transitionScale = 0.95
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                        transitionScale = 1.0
                    }
                }
            }
            return
        }

        feedCounter += 1

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.15, dampingFraction: 0.3)) {
                feedReactionScale = 1.15
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    feedReactionScale = 1.0
                }
            }

            let isNowOverfed = tracker.isOverfed
            showReaction(CreatureReactions.feedReaction(creature: .crawfish, isOverfed: isNowOverfed), duration: 1.5)
        }
    }

    /// Triple-tap punishment: shake + angry reaction + -2% O₂
    private func handlePunishment() {
        isAngry = true
        showReaction(CreatureReactions.punishReaction(creature: .crawfish), duration: 2.0)

        // Angry shake sequence
        let shakeSequence: [(CGFloat, Double)] = [
            (-4, 0.05), (4, 0.05), (-3, 0.05), (3, 0.05), (-2, 0.05), (0, 0.1)
        ]
        var delay = 0.0
        for (offset, dur) in shakeSequence {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.linear(duration: dur)) { jumpOffset = offset }
            }
            delay += dur
        }

        // Penalty: reduce feed bonus (effectively -2% O₂)
        if let tracker = tokenTracker {
            let penalty = Int(Double(tracker.oxygenLevel > 0 ? 1 : 0) * Double(max(1, Int(Double(AppSettings.localOxygenTankCapacity) * 0.02))))
            tracker.feedBonusTokens = max(0, tracker.feedBonusTokens - penalty)
        }

        // Clear angry after 3s
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { isAngry = false }
    }

    // MARK: - Reaction Display Helper

    private func showReaction(_ text: String?, duration: Double = 1.2) {
        guard let text else { return }
        reactionText = text
        reactionOpacity = 1.0
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            withAnimation(.easeOut(duration: 0.3)) { reactionOpacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { reactionText = nil }
        }
    }

    // MARK: - Cross-Creature Interaction (小龙虾侧)

    private func updateInteractionEligibility() {
        let eligible = (state.task == .idle || state.task == .sleeping) && !isDead && !isDragging && !reduceMotion
        InteractionCoordinator.shared.crawfishCanInteract = eligible
    }

    private func handleInteractionPhase(_ phase: InteractionCoordinator.Phase) {
        let coordinator = InteractionCoordinator.shared

        switch phase {
        case .approaching(let type):
            // 暂停游泳，向会合点下沉
            canSwim = false
            let meetX = coordinator.meetingX
            let targetX = (meetX - xPosition) * totalWidth * Self.usableWidthFraction * 0.5
            // 小龙虾下沉到蟹的高度 (y 靠近 crab 的 -25 位置)
            let targetY: CGFloat = -yOffset + (-25)
            withAnimation(.easeInOut(duration: 2.0)) {
                interactionOffset = CGSize(width: targetX - swimOffset, height: targetY)
            }
            showReaction(CreatureReactions.interactionReaction(creature: .crawfish, type: type))

        case .interacting(let type):
            // 播放互动微动画
            switch type {
            case .bump:
                // 碰撞: 向后弹 8pt
                withAnimation(.spring(response: 0.15, dampingFraction: 0.3)) {
                    interactionOffset.width += (facingLeft ? 8 : -8)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        interactionOffset.width -= (facingLeft ? 4 : -4)
                    }
                }
            case .highFive:
                // 碰拳: 小幅前冲 + scale pop
                withAnimation(.spring(response: 0.12, dampingFraction: 0.4)) {
                    transitionScale = 1.15
                    interactionOffset.width += (facingLeft ? -3 : 3)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                        transitionScale = 1.0
                    }
                }
            case .play:
                // 绕圈: 小幅上下摆动
                withAnimation(.easeInOut(duration: 0.6).repeatCount(3, autoreverses: true)) {
                    interactionOffset.height -= 6
                }
            case .nuzzle:
                // 依偎: 轻微左右摇摆
                withAnimation(.easeInOut(duration: 0.8).repeatCount(2, autoreverses: true)) {
                    interactionOffset.width += 4
                }
            }

        case .retreating:
            // 返回原位
            withAnimation(.easeInOut(duration: 1.5)) {
                interactionOffset = .zero
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                canSwim = state.task.canWalk && !isDead && !reduceMotion
                if canSwim { scheduleSwim() }
            }

        case .idle:
            // 确保清理
            if interactionOffset != .zero {
                withAnimation(.easeOut(duration: 0.3)) {
                    interactionOffset = .zero
                }
            }
        }
    }
}

// MARK: - Ground Sprite (Hermit Crab Interactive)

/// 寄居蟹互动精灵 — 底部爬行，壳缩/弹反应
private struct GroundSpriteView: View {
    let state: ClawState
    let xPosition: CGFloat
    let yOffset: CGFloat
    let totalWidth: CGFloat
    let glowOpacity: Double
    var isDead: Bool = false
    var tokenTracker: TokenTracker?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let spriteSize: CGFloat = 72
    private static let usableWidthFraction: CGFloat = 0.8
    private static let leftMarginFraction: CGFloat = 0.1

    // ── Crawling (horizontal only, slower) ──
    @State private var crawlOffset: CGFloat = 0
    @State private var facingLeft: Bool = false
    @State private var canCrawl: Bool = false

    // ── Entry animation ──
    @State private var entryScale: CGFloat = 0.3

    // ── State transition ──
    @State private var transitionScale: CGFloat = 1.0
    @State private var transitionCounter: Int = 0

    // ── Interaction: shell retract (tap) ──
    @State private var shellRetracted: Bool = false
    @State private var tapCooldown: Bool = false
    @State private var reactionText: String? = nil
    @State private var reactionOpacity: Double = 0

    // ── Interaction: triple-tap punishment ──
    @State private var recentTapTimes: [Date] = []
    @State private var isAngry: Bool = false

    // ── Interaction: drag ──
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false

    // ── Interaction: double-tap hearts ──
    @State private var heartCounter: Int = 0

    // ── Interaction: long-press info card ──
    @State private var showInfoCard: Bool = false
    @State private var infoCardDismissId: UUID = UUID()

    // ── Interaction: feeding ──
    @State private var feedCounter: Int = 0
    @State private var feedReactionScale: CGFloat = 1.0

    // ── Cross-creature interaction (互动) ──
    @State private var interactionOffset: CGSize = .zero

    // ── 点击唤醒 ──
    @State private var manuallyAwake: Bool = false

    private var xOffset: CGFloat {
        let usableWidth = totalWidth * Self.usableWidthFraction
        let leftMargin = totalWidth * Self.leftMarginFraction
        return leftMargin + (xPosition * usableWidth) - (totalWidth / 2)
    }

    private var stateColor: Color { state.task.statusColor }

    var body: some View {
        ZStack {
            // Main sprite container
            ZStack {
                // 🐚 Core sprite — hermit crab
                HermitCrabSpriteView(
                    state: state,
                    isSelected: glowOpacity > 0.3,
                    size: Self.spriteSize,
                    isDead: isDead
                )

                // ✨ Transition star particles
                TransitionFXView(
                    triggerCounter: transitionCounter,
                    stateColor: stateColor,
                    size: Self.spriteSize
                )
            }
            .scaleEffect(entryScale * transitionScale * feedReactionScale)
            // Shell retract: shrink briefly on tap
            .scaleEffect(shellRetracted ? 0.8 : 1.0)
            .scaleEffect(x: facingLeft ? -1 : 1, y: 1)
            .frame(width: Self.spriteSize, height: Self.spriteSize)
            .contentShape(Rectangle())
            // ── Gestures: drag (horizontal only for crab) ──
            // highPriorityGesture 确保拖拽优先于 tap/longPress
            .highPriorityGesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            canCrawl = false
                            InteractionCoordinator.shared.cancelInteraction()
                        }
                        // Horizontal only — 寄居蟹是地面生物，只能水平爬行
                        dragOffset = CGSize(width: value.translation.width, height: 0)
                    }
                    .onEnded { _ in
                        isDragging = false
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                            dragOffset = .zero
                        }
                        if (state.task.canWalk || manuallyAwake) && !isDead && !reduceMotion {
                            canCrawl = true
                            scheduleCrawl()
                        }
                        updateInteractionEligibility()
                    }
            )
            .onTapGesture(count: 2) {
                handleDoubleTap()
            }
            .onTapGesture(count: 1) {
                handleSingleTap()
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                handleLongPress()
            }
            .contextMenu {
                if let tracker = tokenTracker {
                    Button {
                        handleFeed(tracker: tracker)
                    } label: {
                        if tracker.isOverfed {
                            Label(L10n.s("feed.overfed"), systemImage: "face.dashed")
                        } else if tracker.canFeed {
                            Label(L10n.s("feed.feed"), systemImage: "fork.knife")
                        } else {
                            let remaining = Int(tracker.feedCooldownRemaining)
                            Label("\(L10n.s("feed.cooldown")) \(remaining)s", systemImage: "clock")
                        }
                    }
                    .disabled(!tracker.canFeed)
                } else {
                    Button {} label: {
                        Label(L10n.s("sprite.noSession"), systemImage: "zzz")
                    }
                    .disabled(true)
                }
            }
            .accessibilityLabel("\(L10n.s("sprite.accessCrab")), \(state.displayName)")
            .accessibilityHint(L10n.s("sprite.accessHint"))

            // ❤️ Heart particles (double-tap)
            HeartParticlesView(triggerCounter: heartCounter, size: Self.spriteSize)

            // 🫧 Bubble dialog above sprite
            PixelBubbleView(task: state.task, isDead: isDead, spriteSize: Self.spriteSize)
                .allowsHitTesting(false)

            // 💬 Reaction text (tap feedback)
            if let reaction = reactionText {
                Text(reaction)
                    .font(DS.Font.monoBold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(DS.Semantic.localAccent.opacity(0.85))
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                            )
                    )
                    .offset(y: -Self.spriteSize * 0.65)
                    .opacity(reactionOpacity)
                    .allowsHitTesting(false)
            }

            // 📋 Info card (long-press)
            SpriteInfoCardView(
                state: state,
                oxygenLevel: tokenTracker?.oxygenLevel ?? 1.0,
                sessionTokens: tokenTracker?.sessionTotalTokens ?? 0,
                isVisible: showInfoCard
            )
            .offset(x: Self.spriteSize * 0.45, y: -Self.spriteSize * 0.3)
            .id(infoCardDismissId)

            // 🍤 Food particles (feeding)
            FoodParticleView(
                triggerCounter: feedCounter,
                targetY: Self.spriteSize * 0.4,
                size: Self.spriteSize * 2
            )
            .offset(y: -Self.spriteSize * 0.3)
        }
        .shadow(color: DS.Semantic.localAccent.opacity(glowOpacity * 0.4), radius: 5)
        .offset(x: xOffset + crawlOffset + interactionOffset.width + dragOffset.width,
                y: yOffset + interactionOffset.height + dragOffset.height)
        .onAppear {
            if reduceMotion {
                entryScale = 1.0
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    entryScale = 1.0
                }
            }
            canCrawl = state.task.canWalk && !isDead && !reduceMotion
            if canCrawl { scheduleCrawl() }
            // 互动: 注册可互动状态
            updateInteractionEligibility()
        }
        .onChange(of: state.task) { _, newTask in
            if !reduceMotion {
                withAnimation(.spring(response: 0.15, dampingFraction: 0.3)) {
                    transitionScale = 1.15
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                        transitionScale = 1.0
                    }
                }
                transitionCounter += 1
            }
            canCrawl = newTask.canWalk && !isDead && !reduceMotion
            if canCrawl { scheduleCrawl() }
            updateInteractionEligibility()
        }
        .onChange(of: isDead) { _, dead in
            canCrawl = state.task.canWalk && !dead && !reduceMotion
            updateInteractionEligibility()
        }
        // ── Cross-creature interaction phase observer ──
        .onChange(of: InteractionCoordinator.shared.phase) { _, newPhase in
            handleInteractionPhase(newPhase)
        }
    }

    // MARK: - Crawling Logic (slower, ground-only)

    private func scheduleCrawl() {
        let delay = Double.random(in: 12.0...20.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard canCrawl else { return }
            performCrawl()
        }
    }

    private func performCrawl() {
        let maxOffset: CGFloat = 15 // Smaller range than crawfish (25)
        let target = CGFloat.random(in: -maxOffset...maxOffset)
        facingLeft = target < crawlOffset

        let duration = Double.random(in: 1.5...3.0) // Slower than crawfish
        withAnimation(.easeInOut(duration: duration)) {
            crawlOffset = target
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.2) {
            guard canCrawl else { return }
            scheduleCrawl()
        }
    }

    // MARK: - Interaction Handlers

    private func handleSingleTap() {
        guard !tapCooldown, !isDead else { return }
        tapCooldown = true

        // Triple-tap punishment detection
        let now = Date()
        recentTapTimes.append(now)
        recentTapTimes.removeAll { now.timeIntervalSince($0) > 2.0 }

        if recentTapTimes.count >= 3 {
            handlePunishment()
            recentTapTimes.removeAll()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { tapCooldown = false }
            return
        }

        // 点击唤醒: 睡眠状态下点击 → 立即开始爬行 60 秒
        if !canCrawl && !isDead && !reduceMotion {
            manuallyAwake = true
            canCrawl = true
            performCrawl()   // ← 立即移动，不等 12-20 秒
            // 60 秒后自动入睡
            DispatchQueue.main.asyncAfter(deadline: .now() + 60.0) {
                guard manuallyAwake else { return }
                manuallyAwake = false
                if !state.task.canWalk {
                    canCrawl = false
                }
            }
        }

        // Shell retract: 寄居蟹性格内向，被戳 → 缩壳 → 慢慢探出
        withAnimation(.spring(response: 0.08, dampingFraction: 0.5)) {
            shellRetracted = true
        }
        // Longer retract for shy personality (0.5s vs crawfish's instant)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                shellRetracted = false
            }
        }

        // State-aware reaction (crab is more laconic)
        showReaction(CreatureReactions.tapReaction(creature: .hermitCrab, task: state.task, isDead: isDead))

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { tapCooldown = false }
    }

    private func handleDoubleTap() {
        guard !isDead else { return }
        heartCounter += 1

        // Shy love reaction — smaller bounce (crab is reserved)
        showReaction(CreatureReactions.loveReaction(creature: .hermitCrab, task: state.task, isDead: isDead), duration: 1.5)

        withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
            transitionScale = 1.08  // Smaller bounce than crawfish (1.15)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                transitionScale = 1.0
            }
        }
    }

    private func handleLongPress() {
        guard !isDead else { return }
        showInfoCard = true
        infoCardDismissId = UUID()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { showInfoCard = false }
    }

    private func handleFeed(tracker: TokenTracker) {
        let wasOverfed = tracker.isOverfed
        guard tracker.feed() else {
            if wasOverfed || tracker.isOverfed {
                showReaction(CreatureReactions.feedReaction(creature: .hermitCrab, isOverfed: true))
                // Crab: retreats into shell when overfed
                withAnimation(.spring(response: 0.1, dampingFraction: 0.5)) {
                    shellRetracted = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                        shellRetracted = false
                    }
                }
            }
            return
        }

        feedCounter += 1

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Smaller reaction (shy)
            withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
                feedReactionScale = 1.08
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                    feedReactionScale = 1.0
                }
            }

            let isNowOverfed = tracker.isOverfed
            showReaction(CreatureReactions.feedReaction(creature: .hermitCrab, isOverfed: isNowOverfed), duration: 1.5)
        }
    }

    /// Triple-tap punishment: deep shell retract + angry reaction + -2% O₂
    private func handlePunishment() {
        isAngry = true
        showReaction(CreatureReactions.punishReaction(creature: .hermitCrab), duration: 2.0)

        // Crab punishment: deep shell retract (shrinks to 0.6 instead of 0.8)
        withAnimation(.spring(response: 0.08, dampingFraction: 0.5)) {
            shellRetracted = true
            transitionScale = 0.6  // Deep retract — scared
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.4)) {
                shellRetracted = false
                transitionScale = 1.0
            }
        }

        // Penalty: reduce feed bonus (effectively -2% O₂)
        if let tracker = tokenTracker {
            let penalty = Int(Double(max(1, AppSettings.localOxygenTankCapacity)) * 0.02)
            tracker.feedBonusTokens = max(0, tracker.feedBonusTokens - penalty)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { isAngry = false }
    }

    // MARK: - Reaction Display Helper

    private func showReaction(_ text: String?, duration: Double = 1.2) {
        guard let text else { return }
        reactionText = text
        reactionOpacity = 1.0
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            withAnimation(.easeOut(duration: 0.3)) { reactionOpacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { reactionText = nil }
        }
    }

    // MARK: - Cross-Creature Interaction (寄居蟹侧)

    private func updateInteractionEligibility() {
        let eligible = (state.task == .idle || state.task == .sleeping) && !isDead && !isDragging && !reduceMotion
        InteractionCoordinator.shared.crabCanInteract = eligible
    }

    private func handleInteractionPhase(_ phase: InteractionCoordinator.Phase) {
        let coordinator = InteractionCoordinator.shared

        switch phase {
        case .approaching(let type):
            // 暂停爬行，向会合点移动 (蟹只做水平移动)
            canCrawl = false
            let meetX = coordinator.meetingX
            let targetX = (meetX - xPosition) * totalWidth * Self.usableWidthFraction * 0.5
            withAnimation(.easeInOut(duration: 2.0)) {
                interactionOffset = CGSize(width: targetX - crawlOffset, height: 0)
            }
            showReaction(CreatureReactions.interactionReaction(creature: .hermitCrab, type: type))

        case .interacting(let type):
            // 播放互动微动画 — 蟹的反应更内向
            switch type {
            case .bump:
                // 碰撞: 缩壳 + 弹回
                withAnimation(.spring(response: 0.08, dampingFraction: 0.5)) {
                    shellRetracted = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                        shellRetracted = false
                        interactionOffset.width += (facingLeft ? -6 : 6)
                    }
                }
            case .highFive:
                // 碰拳: 壳摇晃 + 小 scale
                withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) {
                    transitionScale = 1.08
                    interactionOffset.width += (facingLeft ? 3 : -3)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                        transitionScale = 1.0
                    }
                }
            case .play:
                // 绕圈: 蟹小幅左右挪动
                withAnimation(.easeInOut(duration: 0.7).repeatCount(3, autoreverses: true)) {
                    interactionOffset.width += 5
                }
            case .nuzzle:
                // 依偎: 靠近 + 轻微壳晃
                withAnimation(.easeInOut(duration: 0.9).repeatCount(2, autoreverses: true)) {
                    interactionOffset.width -= 3
                }
            }

        case .retreating:
            // 返回原位
            withAnimation(.easeInOut(duration: 1.5)) {
                interactionOffset = .zero
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                canCrawl = state.task.canWalk && !isDead && !reduceMotion
                if canCrawl { scheduleCrawl() }
            }

        case .idle:
            if interactionOffset != .zero {
                withAnimation(.easeOut(duration: 0.3)) {
                    interactionOffset = .zero
                }
            }
        }
    }
}
