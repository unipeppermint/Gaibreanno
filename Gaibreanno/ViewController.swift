import UIKit

final class ViewController: UIViewController, UIGestureRecognizerDelegate {
    private enum Screen { case lobby, deck, library, battle, reward }
    private let store = GameStore()
    private let backdrop = GameBackdrop()
    private let scroll = UIScrollView()
    private let content = UIView()
    private var navigation = UIView()
    private var screen: Screen = .lobby
    private var selectedCard: CardKind?
    private var selectedReward: CardKind?
    private var draftDeck: [CardKind]?
    private var lanes: [LaneView] = []
    private var ghost: CardView?
    private var lastSize = CGSize.zero
    private var lastSafeInsets = UIEdgeInsets.zero
    private var toastView: UIView?
    private var toastGeneration = 0
    private var settlingTurn = false
    private var width: CGFloat { min(view.bounds.width, 520) }
    private var inner: CGFloat { width - 32 }
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = UIColor(hex: 0x11154E)
        view.addSubview(backdrop)
        scroll.showsVerticalScrollIndicator = false
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.alwaysBounceVertical = false
        view.addSubview(scroll); scroll.addSubview(content)
        if store.state.battle?.outcome == .won {
            screen = .reward
            selectedReward = store.state.rewards.first
        }
        NotificationCenter.default.addObserver(self, selector: #selector(saveGame), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard view.bounds.size != lastSize || view.safeAreaInsets != lastSafeInsets else { return }
        lastSize = view.bounds.size; lastSafeInsets = view.safeAreaInsets
        redraw()
    }
    @objc private func saveGame() { store.save() }
    private func feedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        if store.state.haptics { UIImpactFeedbackGenerator(style: style).impactOccurred() }
    }
    private func show(_ destination: Screen) {
        toastView?.removeFromSuperview()
        toastGeneration += 1
        selectedCard = nil
        if destination == .deck { draftDeck = store.state.deck }
        screen = destination
        feedback()
        redraw()
        scroll.setContentOffset(.zero, animated: false)
    }
    private func redraw(preserveScroll: Bool = false) {
        let offset = scroll.contentOffset
        backdrop.frame = view.bounds
        let hasNav = screen == .lobby || screen == .deck || screen == .library
        let navHeight: CGFloat = hasNav ? 72 : 0
        scroll.frame = CGRect(x: 0, y: view.safeAreaInsets.top + 2, width: view.bounds.width,
                              height: view.bounds.height - view.safeAreaInsets.top - view.safeAreaInsets.bottom - navHeight - 2)
        content.subviews.forEach { $0.removeFromSuperview() }
        lanes.removeAll()
        navigation.removeFromSuperview()
        content.frame = CGRect(x: (view.bounds.width - width) / 2, y: 0, width: width, height: 0)
        let height: CGFloat
        switch screen {
        case .lobby: height = buildLobby()
        case .deck: height = buildCollection(editing: true)
        case .library: height = buildCollection(editing: false)
        case .battle: height = buildBattle()
        case .reward: height = buildReward()
        }
        content.frame.size.height = height
        scroll.contentSize = CGSize(width: view.bounds.width, height: height)
        if hasNav { buildNavigation() }
        if preserveScroll { scroll.contentOffset = CGPoint(x: 0, y: min(offset.y, max(0, height - scroll.bounds.height))) }
        else { scroll.contentOffset = .zero }
    }

    @discardableResult private func label(_ text: String, _ frame: CGRect, size: CGFloat = 16,
                                         color: UIColor = .white, align: NSTextAlignment = .left,
                                         parent: UIView? = nil, weight: UIFont.Weight = .bold) -> UILabel {
        let l = gameLabel(text, size: size, color: color, weight: weight, alignment: align)
        l.frame = frame; (parent ?? content).addSubview(l); return l
    }
    @discardableResult private func button(_ title: String, _ frame: CGRect, primary: Bool = false,
                                          icon: String? = nil, parent: UIView? = nil, action: @escaping () -> Void) -> GameButton {
        let b = GameButton(title, primary: primary, symbol: icon); b.frame = frame; b.onTap = action
        (parent ?? content).addSubview(b); return b
    }
    private func art(_ index: Int, _ frame: CGRect, parent: UIView? = nil, radius: CGFloat = 12) -> UIImageView {
        let v = UIImageView(image: GameArt.image(index)); v.frame = frame
        v.contentMode = .scaleAspectFill; v.clipsToBounds = true; v.layer.cornerRadius = radius
        (parent ?? content).addSubview(v); return v
    }
    private func title(_ text: String, frame: CGRect, color: UIColor = Palette.yellow, size: CGFloat = 48) {
        let l = OutlinedLabel(); l.text = text; l.textColor = color
        l.font = Palette.font(size, .black); l.textAlignment = .center
        l.adjustsFontSizeToFitWidth = true; l.minimumScaleFactor = 0.6
        l.frame = frame; l.layer.shadowColor = UIColor(hex: 0x080B35).cgColor
        l.layer.shadowOffset = CGSize(width: 0, height: 4); l.layer.shadowOpacity = 1; l.layer.shadowRadius = 0
        content.addSubview(l)
    }
    private func addDetailsGesture(_ card: CardView) {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(cardLongPressed(_:)))
        card.addGestureRecognizer(longPress)
    }
    @objc private func cardLongPressed(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, let card = gesture.view as? CardView else { return }
        feedback(.medium); showCardDetail(card.kind)
    }

    private func buildLobby() -> CGFloat {
        let compact = scroll.bounds.height < 650
        title("时空牌局", frame: CGRect(x: 22, y: 3, width: width - 90, height: compact ? 51 : 68), size: compact ? 43 : 51)
        button("", CGRect(x: width - 60, y: compact ? 9 : 17, width: 42, height: 42), icon: "gearshape.fill") { [weak self] in self?.showSettings() }.accessibilityLabel = "设置"
        let stageIndex = store.state.selectedStage
        let stage = Stage.all[stageIndex]
        let chapter = button("第 \(stageIndex + 1) 章 · \(stage.region)  ⌄", CGRect(x: 56, y: compact ? 61 : 79, width: width - 112, height: 33)) { [weak self] in self?.chooseStage() }
        chapter.titleLabel?.font = Palette.font(14, .heavy)
        let cardW = (inner - 40) / 3
        let cardH = cardW * (compact ? 1.38 : 1.45)
        let panelY: CGFloat = compact ? 103 : 128
        let panelH = cardH * 2 + (compact ? 57 : 67)
        let panel = GamePanel(); panel.frame = CGRect(x: 16, y: panelY, width: inner, height: panelH); content.addSubview(panel)
        label("我的卡组", CGRect(x: 14, y: 10, width: 150, height: 26), size: 20, parent: panel, weight: .heavy)
        label("6 / 6", CGRect(x: inner - 90, y: 10, width: 73, height: 26), size: 20, color: Palette.cyan, align: .right, parent: panel, weight: .heavy)
        for (index, kind) in store.state.deck.enumerated() {
            let card = CardView(kind)
            card.frame = CGRect(x: 10 + CGFloat(index % 3) * (cardW + 10), y: (compact ? 40 : 46) + CGFloat(index / 3) * (cardH + (compact ? 8 : 10)), width: cardW, height: cardH)
            card.onTap = { [weak self] in self?.showCardDetail(kind) }
            card.accessibilityIdentifier = "deckcard.\(kind.rawValue)"
            panel.addSubview(card)
        }
        let challengeY = panelY + panelH + (compact ? 10 : 14)
        let challenge = GamePanel(color: UIColor(hex: 0x22358F)); challenge.frame = CGRect(x: 16, y: challengeY, width: inner, height: compact ? 60 : 70); content.addSubview(challenge)
        _ = art(6, CGRect(x: 5, y: 5, width: compact ? 50 : 60, height: compact ? 50 : 60), parent: challenge)
        label("\(store.state.completedStages.contains(stageIndex) ? "再次挑战" : "下一关")  ·  已通关 \(store.state.completedStages.count)/3", CGRect(x: 77, y: 9, width: inner - 106, height: 19), size: 11, color: Palette.quiet, parent: challenge)
        label(stage.name, CGRect(x: 77, y: compact ? 26 : 31, width: inner - 103, height: 29), size: 23, parent: challenge, weight: .heavy)
        let choose = UIButton(frame: challenge.bounds); choose.accessibilityLabel = "选择关卡"
        choose.addTarget(self, action: #selector(stageButtonTapped), for: .touchUpInside); challenge.addSubview(choose)
        label("›", CGRect(x: inner - 29, y: 22, width: 20, height: 30), size: 28, parent: challenge)
        let battle = store.state.battle
        let startText = battle == nil ? "开始牌局" : (battle?.outcome == .won ? "领取奖励" : battle?.outcome == .lost ? "再次挑战" : "继续牌局")
        let start = button(startText, CGRect(x: 18, y: challengeY + (compact ? 72 : 86), width: inner - 4, height: compact ? 50 : 58), primary: true, icon: "bolt.shield.fill") { [weak self] in self?.startOrResume() }
        start.accessibilityIdentifier = "startBattle"
        return challengeY + (compact ? 126 : 160)
    }
    @objc private func stageButtonTapped() { chooseStage() }

    private func buildNavigation() {
        navigation = UIView(frame: CGRect(x: (view.bounds.width - width) / 2, y: view.bounds.height - view.safeAreaInsets.bottom - 68, width: width, height: 68 + view.safeAreaInsets.bottom))
        navigation.backgroundColor = UIColor(hex: 0x0D164F)
        let line = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 1)); line.backgroundColor = UIColor(hex: 0x4459A7); navigation.addSubview(line)
        let titles = ["冒险", "卡组", "图鉴"], icons = ["mountain.2.fill", "rectangle.on.rectangle.angled", "book.closed.fill"]
        let pages: [Screen] = [.lobby, .deck, .library]
        for i in 0..<3 {
            let tab = UIButton(frame: CGRect(x: CGFloat(i) * width / 3, y: 1, width: width / 3, height: 67))
            let active = screen == pages[i]
            if active {
                tab.backgroundColor = UIColor(hex: 0x213C9A)
                let glow = UIView(frame: CGRect(x: 23, y: 0, width: width / 3 - 46, height: 3)); glow.backgroundColor = Palette.cyan; tab.addSubview(glow)
            }
            let iv = UIImageView(image: UIImage(systemName: icons[i]) ?? UIImage(systemName: "map.fill")); iv.tintColor = active ? Palette.cyan : Palette.quiet
            iv.contentMode = .scaleAspectFit; iv.frame = CGRect(x: tab.bounds.midX - 13, y: 9, width: 26, height: 25); tab.addSubview(iv)
            label(titles[i], CGRect(x: 0, y: 39, width: tab.bounds.width, height: 21), size: 13, color: active ? .white : Palette.quiet, align: .center, parent: tab)
            tab.tag = i; tab.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            tab.accessibilityLabel = titles[i]; tab.accessibilityTraits = active ? [.button, .selected] : .button
            tab.accessibilityIdentifier = "tab.\(i)"
            navigation.addSubview(tab)
        }
        view.addSubview(navigation)
    }
    @objc private func tabTapped(_ sender: UIButton) { show([.lobby, .deck, .library][sender.tag]) }

    private func buildCollection(editing: Bool) -> CGFloat {
        title(editing ? "我的卡组" : "时空图鉴", frame: CGRect(x: 16, y: 6, width: inner, height: 57), size: 38)
        let cards = editing ? store.state.collection : CardKind.allCases
        let current = draftDeck ?? store.state.deck
        label(editing ? "选择 6 张卡牌 · 长按查看效果" : "收集 \(store.state.collection.count) / \(CardKind.allCases.count) · 通关解锁新卡", CGRect(x: 16, y: 68, width: inner, height: 25), size: 13, color: Palette.quiet, align: .center)
        if editing {
            label("已选 \(current.count) / 6", CGRect(x: 16, y: 101, width: inner, height: 23), size: 17, color: current.count == 6 ? Palette.green : Palette.yellow, align: .center)
        }
        let cardW = (inner - 20) / 3, cardH = cardW * 1.49
        let gridY: CGFloat = editing ? 141 : 111
        for (i, kind) in cards.enumerated() {
            let card = CardView(kind)
            card.frame = CGRect(x: 16 + CGFloat(i % 3) * (cardW + 10), y: gridY + CGFloat(i / 3) * (cardH + 22), width: cardW, height: cardH)
            card.selectedCard = editing && current.contains(kind)
            card.locked = !store.state.collection.contains(kind)
            card.accessibilityIdentifier = "collection.\(kind.rawValue)"
            card.onTap = { [weak self] in
                guard let self = self else { return }
                if editing { self.toggleDeck(kind) } else { self.showCardDetail(kind) }
            }
            addDetailsGesture(card)
            content.addSubview(card)
            if editing && current.contains(kind) {
                let check = UILabel(frame: CGRect(x: card.frame.maxX - 25, y: card.frame.minY - 7, width: 27, height: 27))
                check.text = "✓"; check.textAlignment = .center; check.textColor = Palette.ink; check.font = Palette.font(17, .heavy)
                check.backgroundColor = Palette.green; check.layer.cornerRadius = 13.5; check.clipsToBounds = true; content.addSubview(check)
            }
            if card.locked {
                label("通关解锁", CGRect(x: card.frame.minX, y: card.frame.maxY + 3, width: cardW, height: 16), size: 10, color: Palette.quiet, align: .center)
            }
        }
        let bottom = gridY + CGFloat((cards.count + 2) / 3) * (cardH + 22)
        if editing {
            let save = button("保存卡组  \(current.count)/6", CGRect(x: 18, y: bottom + 3, width: inner - 4, height: 55), primary: true) { [weak self] in
                guard let self = self, let deck = self.draftDeck, deck.count == 6 else { return }
                self.store.state.deck = deck; self.store.save(); self.show(.lobby); self.toast("卡组已保存，下次新牌局生效")
            }
            save.isEnabled = current.count == 6
            save.accessibilityIdentifier = "saveDeck"
            return bottom + 80
        }
        return bottom + 12
    }
    private func toggleDeck(_ kind: CardKind) {
        guard var draft = draftDeck else { return }
        if let i = draft.firstIndex(of: kind) { draft.remove(at: i) }
        else if draft.count < 6 { draft.append(kind) }
        else { toast("卡组已满，先移除一张卡牌"); return }
        draftDeck = draft; feedback(); redraw(preserveScroll: true)
    }

    private func buildBattle() -> CGFloat {
        guard let battle = store.state.battle else { screen = .lobby; return buildLobby() }
        let compact = scroll.bounds.height < 710
        let enemyY: CGFloat = compact ? 52 : 64
        let enemyH: CGFloat = compact ? 94 : 120
        let laneY = enemyY + enemyH + 14
        button("", CGRect(x: 16, y: 5, width: 42, height: 40), icon: "chevron.left") { [weak self] in self?.leaveBattle() }.accessibilityLabel = "返回大厅"
        label(battle.stage.name, CGRect(x: 64, y: 4, width: width - 128, height: 27), size: 20, align: .center, weight: .heavy)
        label("第 \(battle.stageIndex + 1) 章 · \(battle.stage.region)", CGRect(x: 64, y: 32, width: width - 128, height: 18), size: 11, color: Palette.quiet, align: .center)
        button("", CGRect(x: width - 58, y: 5, width: 42, height: 40), icon: "questionmark") { [weak self] in self?.showRules() }.accessibilityLabel = "玩法说明"
        let enemy = GamePanel(color: UIColor(hex: 0x253991)); enemy.frame = CGRect(x: 16, y: enemyY, width: inner, height: enemyH); content.addSubview(enemy)
        _ = art(6, CGRect(x: 7, y: 7, width: enemyH - 14, height: enemyH - 14), parent: enemy, radius: 14)
        label(battle.stage.enemy, CGRect(x: enemyH + 9, y: compact ? 6 : 11, width: inner - enemyH - 23, height: 26), size: 21, parent: enemy, weight: .heavy)
        let bar = HealthBar(current: battle.enemyHealth, maximum: battle.stage.health)
        bar.frame = CGRect(x: enemyH + 8, y: compact ? 34 : 44, width: inner - enemyH - 23, height: 23); enemy.addSubview(bar)
        let intent = label("下回合  ⚡ \(battle.enemyIntent)", CGRect(x: enemyH + 8, y: compact ? 62 : 76, width: inner - enemyH - 23, height: compact ? 25 : 33), size: 16, color: UIColor(hex: 0xFFF0C1), align: .center, parent: enemy, weight: .heavy)
        intent.backgroundColor = UIColor(hex: 0xB2365D); intent.layer.cornerRadius = 10; intent.clipsToBounds = true
        let laneW = (inner - 16) / 3
        let laneH = compact ? min(180, laneW * 1.35 + 57) : laneW * 1.35 + 57
        for lane in TimeLane.allCases {
            let laneView = LaneView(lane, card: battle.field[lane.rawValue])
            laneView.frame = CGRect(x: 16 + CGFloat(lane.rawValue) * (laneW + 8), y: laneY, width: laneW, height: laneH)
            laneView.accepting = selectedCard.map { battle.canPlay($0, in: lane) == nil } ?? false
            laneView.onTap = { [weak self] in self?.laneTapped(lane) }
            content.addSubview(laneView); lanes.append(laneView)
        }
        let hudY = laneY + laneH + 12
        let hud = GamePanel(color: UIColor(hex: 0x112460)); hud.frame = CGRect(x: 16, y: hudY, width: inner, height: 42); content.addSubview(hud)
        label("♥ \(battle.playerHealth)/20", CGRect(x: 11, y: 8, width: inner * 0.26, height: 25), size: 16, color: UIColor(hex: 0xFF8BB2), parent: hud, weight: .heavy)
        label("⬡ \(battle.shield)", CGRect(x: inner * 0.29, y: 8, width: inner * 0.15, height: 25), size: 15, color: Palette.cyan, parent: hud)
        label("ϟ \(battle.energy)/5", CGRect(x: inner * 0.48, y: 8, width: inner * 0.23, height: 25), size: 18, color: Palette.cyan, parent: hud, weight: .heavy)
        label("第 \(battle.turn) 回合", CGRect(x: inner * 0.74, y: 8, width: inner * 0.23, height: 25), size: 12, color: .white, align: .right, parent: hud)
        let hintY = hudY + (compact ? 47 : 51)
        let hintText = selectedCard.map { "\($0.name) · 点击高亮卡槽出牌" } ?? "点击或拖动手牌，选择时间卡槽"
        label(hintText, CGRect(x: 16, y: hintY, width: inner, height: 22), size: 12, color: selectedCard == nil ? Palette.quiet : Palette.yellow, align: .center)
        let handY = hintY + (compact ? 31 : 41)
        let cardW: CGFloat = min(112, inner * 0.295), cardH = cardW * (compact ? 1.30 : 1.42)
        let n = battle.hand.count
        let spread = min(cardW * 0.79, (inner - cardW - 10) / CGFloat(max(1, n - 1)))
        let handWidth = cardW + CGFloat(max(0, n - 1)) * spread
        for (i, kind) in battle.hand.enumerated() {
            let card = CardView(kind)
            let centered = CGFloat(i) - CGFloat(n - 1) / 2
            card.frame = CGRect(x: (width - handWidth) / 2 + CGFloat(i) * spread, y: handY + abs(centered) * 4, width: cardW, height: cardH)
            card.transform = CGAffineTransform(rotationAngle: centered * 0.075)
            if selectedCard == kind {
                card.center.y -= 15
                card.selectedCard = true
                card.layer.zPosition = 20
            }
            if kind.cost > battle.energy { card.alpha = 0.56 }
            card.onTap = { [weak self] in
                guard let self = self, !self.settlingTurn else { return }
                self.selectedCard = self.selectedCard == kind ? nil : kind
                self.feedback(); self.redraw(preserveScroll: true)
            }
            card.accessibilityIdentifier = "hand.\(kind.rawValue)"
            card.onDrop = { [weak self] windowPoint in
                guard let self = self, !self.settlingTurn else { return }
                let point = self.view.convert(windowPoint, from: self.view.window)
                if let target = self.lanes.first(where: { $0.convert($0.bounds, to: self.view).contains(point) }) {
                    self.play(kind, in: target.lane)
                }
            }
            addDetailsGesture(card)
            let pan = UIPanGestureRecognizer(target: self, action: #selector(dragCard(_:)))
            pan.delegate = self; card.addGestureRecognizer(pan)
            scroll.panGestureRecognizer.require(toFail: pan)
            content.addSubview(card)
        }
        if n == 0 {
            label("手牌用完了，结束回合抽取新卡", CGRect(x: 25, y: handY + 52, width: width - 50, height: 45), size: 15, color: Palette.quiet, align: .center)
        }
        let footerY = handY + cardH + (compact ? 16 : 22)
        button("战斗记录", CGRect(x: 16, y: footerY + 5, width: 107, height: 44), icon: "list.bullet") { [weak self] in self?.showBattleLog() }.accessibilityIdentifier = "battleLog"
        let end = button("结束回合", CGRect(x: width - 185, y: footerY, width: 169, height: 53), primary: true) { [weak self] in self?.endTurn() }
        end.isEnabled = battle.outcome == .playing && !settlingTurn
        end.accessibilityIdentifier = "endTurn"
        if battle.outcome == .lost {
            showDefeatOverlay(afterLayout: true)
        }
        return footerY + (compact ? 66 : 74)
    }

    private func laneTapped(_ lane: TimeLane) {
        guard !settlingTurn else { return }
        guard let card = selectedCard else {
            if let field = store.state.battle?.field[lane.rawValue] { showCardDetail(field.kind) }
            else { toast(lane.hint + " · 先选择一张手牌") }
            return
        }
        play(card, in: lane)
    }
    private func play(_ card: CardKind, in lane: TimeLane) {
        guard var battle = store.state.battle, !settlingTurn else { return }
        if let error = battle.play(card, in: lane) { toast(error); return }
        store.state.battle = battle; store.save(); selectedCard = nil
        feedback(.medium)
        if battle.outcome == .won { showVictory(); return }
        redraw(preserveScroll: true)
        if !store.state.reducedMotion && !UIAccessibility.isReduceMotionEnabled,
           let target = lanes.first(where: { $0.lane == lane }) {
            target.transform = CGAffineTransform(scaleX: 0.93, y: 0.93)
            UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.7, options: []) { target.transform = .identity }
        }
        toast(battle.log.last ?? "出牌成功")
    }
    @objc private func dragCard(_ gesture: UIPanGestureRecognizer) {
        guard let source = gesture.view as? CardView, !settlingTurn else { return }
        let point = gesture.location(in: view)
        switch gesture.state {
        case .began:
            selectedCard = source.kind
            let copy = CardView(source.kind); copy.frame = CGRect(origin: .zero, size: source.bounds.size)
            copy.selectedCard = true; copy.isUserInteractionEnabled = false
            copy.center = CGPoint(x: point.x, y: point.y - 50)
            view.addSubview(copy); ghost = copy; source.alpha = 0.3; feedback()
            for lane in lanes { lane.accepting = store.state.battle?.canPlay(source.kind, in: lane.lane) == nil }
        case .changed:
            ghost?.center = CGPoint(x: point.x, y: point.y - 50)
        case .ended:
            let target = lanes.first { $0.convert($0.bounds, to: view).contains(point) }
            ghost?.removeFromSuperview(); ghost = nil; source.alpha = 1
            if let target = target { play(source.kind, in: target.lane) }
            else { selectedCard = nil; redraw(preserveScroll: true) }
        case .cancelled, .failed:
            ghost?.removeFromSuperview(); ghost = nil; source.alpha = 1; selectedCard = nil; redraw(preserveScroll: true)
        default: break
        }
    }
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // A hand card can be dragged diagonally to any lane. Direction filtering
        // rejects short first movements from touch and accessibility pointers.
        return store.state.battle?.outcome == .playing && !settlingTurn
    }
    private func endTurn() {
        guard var battle = store.state.battle, !settlingTurn, battle.outcome == .playing else { return }
        toastView?.removeFromSuperview()
        toastGeneration += 1
        battle.endTurn(); store.state.battle = battle; store.save(); selectedCard = nil
        feedback(.heavy)
        if battle.outcome == .won { showVictory(); return }
        settlingTurn = true; redraw(preserveScroll: true)
        let reduce = store.state.reducedMotion || UIAccessibility.isReduceMotionEnabled
        if !reduce {
            content.transform = CGAffineTransform(translationX: -4, y: 0)
            UIView.animate(withDuration: 0.28, delay: 0, usingSpringWithDamping: 0.3, initialSpringVelocity: 0.5, options: []) { self.content.transform = .identity }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduce ? 0 : 0.32)) { [weak self] in
            guard let self = self else { return }
            self.settlingTurn = false
            if self.screen == .battle {
                self.redraw(preserveScroll: true)
                if battle.outcome == .playing { self.toast("第 \(battle.turn) 回合 · 能量已恢复") }
            }
        }
    }
    private func showVictory() {
        selectedReward = store.state.rewards.count > 1 ? store.state.rewards[1] : store.state.rewards.first
        show(.reward)
        if store.state.haptics { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    }

    private func buildReward() -> CGFloat {
        guard let battle = store.state.battle, battle.outcome == .won else { screen = .lobby; return buildLobby() }
        let choices = store.state.rewards
        let star = UILabel(frame: CGRect(x: 16, y: 6, width: inner, height: 41)); star.text = "✦  ★  ✦"
        star.font = Palette.font(31, .black); star.textColor = Palette.yellow; star.textAlignment = .center; content.addSubview(star)
        title("胜利！", frame: CGRect(x: 20, y: 48, width: width - 40, height: 86), size: 71)
        label(choices.isEmpty ? "全部卡牌已收集，再战刷新纪录" : "选择一张加入卡组", CGRect(x: 36, y: 139, width: width - 72, height: 34), size: 20, align: .center, weight: .heavy)
        let rewards = choices.isEmpty ? Array(store.state.deck.prefix(3)) : choices
        if selectedReward == nil { selectedReward = rewards.first }
        let cardW = inner * 0.365, cardH = cardW * 1.5
        for (i, kind) in rewards.enumerated() {
            let card = CardView(kind)
            let fraction = rewards.count == 1 ? 0.5 : CGFloat(i) / CGFloat(rewards.count - 1)
            card.frame = CGRect(x: 16 + fraction * (inner - cardW), y: 208 + (i == 1 ? 0 : 25), width: cardW, height: cardH)
            card.transform = CGAffineTransform(rotationAngle: (CGFloat(i) - CGFloat(rewards.count - 1) / 2) * 0.13)
            card.selectedCard = selectedReward == kind
            card.layer.zPosition = selectedReward == kind ? 10 : CGFloat(i)
            card.onTap = { [weak self] in self?.selectedReward = kind; self?.feedback(); self?.redraw(preserveScroll: true) }
            card.accessibilityIdentifier = "reward.\(kind.rawValue)"
            content.addSubview(card)
        }
        let detailY = 208 + cardH + 65
        let selected = selectedReward ?? .elder
        let panel = GamePanel(); panel.frame = CGRect(x: 18, y: detailY, width: inner - 4, height: 94); content.addSubview(panel)
        _ = art(selected.art, CGRect(x: 8, y: 8, width: 78, height: 78), parent: panel)
        label(selected.name, CGRect(x: 99, y: 11, width: inner - 120, height: 29), size: 23, parent: panel, weight: .heavy)
        label(selected.isUnit ? "放入过去，下回合成长" : selected.keyword, CGRect(x: 99, y: 44, width: inner - 120, height: 22), size: 13, parent: panel)
        label("\(selected.cost) 点能量 · \(selected.isUnit ? "成长型" : "法术型")", CGRect(x: 99, y: 69, width: inner - 120, height: 17), size: 11, color: selected.tint, parent: panel)
        label("\(battle.turn) 回合获胜   ·   抵挡 \(battle.damageBlocked) 点伤害", CGRect(x: 16, y: detailY + 109, width: inner, height: 23), size: 13, color: Palette.quiet, align: .center)
        let claim = button(choices.isEmpty ? "完成挑战" : "加入卡组", CGRect(x: 18, y: detailY + 147, width: inner - 4, height: 58), primary: true) { [weak self] in self?.claimReward() }
        claim.accessibilityIdentifier = "claimReward"
        button("查看卡牌效果", CGRect(x: 80, y: detailY + 225, width: width - 160, height: 41)) { [weak self] in self?.showCardDetail(selected) }
        return detailY + 286
    }
    private func claimReward() {
        guard store.state.battle?.outcome == .won else { return }
        let choices = store.state.rewards
        if choices.isEmpty { completeReward(nil, replacing: nil); return }
        guard let selected = selectedReward, choices.contains(selected) else { toast("请先选择一张奖励卡牌"); return }
        let sheet = UIAlertController(title: "将\(selected.name)加入卡组", message: "卡组上限为 6 张，选择要替换的卡牌。旧卡仍保留在图鉴中。", preferredStyle: .actionSheet)
        for kind in store.state.deck {
            sheet.addAction(UIAlertAction(title: "替换 \(kind.name)", style: .default) { [weak self] _ in self?.completeReward(selected, replacing: kind) })
        }
        sheet.addAction(UIAlertAction(title: "仅加入收藏", style: .default) { [weak self] _ in self?.completeReward(selected, replacing: nil) })
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))
        presentSheet(sheet)
    }
    private func completeReward(_ reward: CardKind?, replacing old: CardKind?) {
        guard store.state.claimVictory(reward) else { return }
        if let reward = reward, let old = old, let i = store.state.deck.firstIndex(of: old) { store.state.deck[i] = reward }
        store.save(); show(.lobby)
        toast(reward.map { "\($0.name)已解锁！" } ?? "挑战完成！全部卡牌已收集")
    }

    private func startOrResume() {
        if store.state.battle?.outcome == .won { showVictory(); return }
        if store.state.battle == nil || store.state.battle?.outcome == .lost { store.state.startBattle(); store.save() }
        show(.battle)
        if !store.state.hasSeenRules {
            store.state.hasSeenRules = true; store.save()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in self?.showRules() }
        }
    }
    private func leaveBattle() {
        if store.state.battle?.outcome == .lost { store.state.battle = nil }
        store.save(); show(.lobby)
        toast("牌局已保存，可随时继续")
    }
    private func chooseStage() {
        let alert = UIAlertController(title: "选择关卡", message: "每次通关解锁下一关和一张新卡", preferredStyle: .actionSheet)
        for (i, stage) in Stage.all.enumerated() {
            let action = UIAlertAction(title: "\(i > store.state.unlockedStage ? "🔒 " : store.state.completedStages.contains(i) ? "✓ " : "")第 \(i + 1) 章 · \(stage.name)", style: .default) { [weak self] _ in
                guard let self = self else { return }
                if self.store.state.battle != nil {
                    let confirm = UIAlertController(title: "开始新的牌局？", message: "当前牌局进度将被替换，已获得的卡牌和通关记录会保留。", preferredStyle: .alert)
                    confirm.addAction(UIAlertAction(title: "保留当前牌局", style: .cancel))
                    confirm.addAction(UIAlertAction(title: "切换关卡", style: .destructive) { [weak self] _ in self?.selectStage(i) })
                    self.present(confirm, animated: true)
                } else { self.selectStage(i) }
            }
            action.isEnabled = i <= store.state.unlockedStage
            alert.addAction(action)
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel)); presentSheet(alert)
    }
    private func selectStage(_ index: Int) {
        store.state.selectedStage = index; store.state.battle = nil; store.save(); redraw()
    }
    private func showDefeatOverlay(afterLayout: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.screen == .battle, self.store.state.battle?.outcome == .lost, self.presentedViewController == nil else { return }
            let alert = UIAlertController(title: "时间线失守", message: "试试让种子炮台在过去成长，并及时使用护盾抵挡攻击。卡组与收集进度不会丢失。", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "重新挑战", style: .default) { [weak self] _ in
                guard let self = self else { return }
                self.store.state.startBattle(); self.store.save(); self.redraw()
            })
            alert.addAction(UIAlertAction(title: "调整卡组", style: .default) { [weak self] _ in
                self?.store.state.battle = nil; self?.store.save(); self?.show(.deck)
            })
            alert.addAction(UIAlertAction(title: "返回大厅", style: .cancel) { [weak self] _ in self?.leaveBattle() })
            self.present(alert, animated: true)
        }
    }
    private func showRules() {
        let message = "目标：在生命耗尽前击败敌人。\n\n① 选择手牌，再点击时间卡槽，也可直接拖动。\n\n过去：仅限单位，等待一回合后永久攻击 +2。\n现在：单位本回合出击，法术立即生效。\n未来：等待一回合，单位首次攻击或法术效果翻倍。\n\n结束回合：己方出击 → 敌方攻击 → 恢复能量 → 等待卡激活 → 抽 2 张牌。每 3 回合敌人攻击 +2。\n\n长按卡牌查看效果。护盾可保留，能量上限 5，手牌上限 6。"
        let alert = UIAlertController(title: "掌握时间，打出连锁", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "开始出牌", style: .default))
        present(alert, animated: true)
    }
    private func showBattleLog() {
        let alert = UIAlertController(title: "战斗记录", message: store.state.battle?.log.suffix(14).joined(separator: "\n\n"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "继续牌局", style: .default)); present(alert, animated: true)
    }
    private func showSettings() {
        let alert = UIAlertController(title: "设置", message: "进度自动保存在本机", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "触感反馈：\(store.state.haptics ? "开启" : "关闭")", style: .default) { [weak self] _ in
            guard let self = self else { return }; self.store.state.haptics.toggle(); self.store.save(); self.toast(self.store.state.haptics ? "触感反馈已开启" : "触感反馈已关闭")
        })
        alert.addAction(UIAlertAction(title: "减少动态效果：\(store.state.reducedMotion ? "开启" : "关闭")", style: .default) { [weak self] _ in
            guard let self = self else { return }; self.store.state.reducedMotion.toggle(); self.store.save(); self.toast("显示设置已保存")
        })
        alert.addAction(UIAlertAction(title: "玩法说明", style: .default) { [weak self] _ in self?.showRules() })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel)); presentSheet(alert)
    }
    private func showCardDetail(_ kind: CardKind) {
        let detail = CardDetailController(kind: kind, owned: store.state.collection.contains(kind))
        detail.modalPresentationStyle = .overFullScreen
        detail.modalTransitionStyle = .crossDissolve
        present(detail, animated: !store.state.reducedMotion)
    }
    private func presentSheet(_ sheet: UIAlertController) {
        sheet.popoverPresentationController?.sourceView = view
        sheet.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.maxY - 90, width: 1, height: 1)
        present(sheet, animated: true)
    }
    private func toast(_ text: String) {
        toastView?.removeFromSuperview(); toastGeneration += 1
        let generation = toastGeneration
        let panel = GamePanel(color: UIColor(hex: 0x080F3F), border: Palette.cyan)
        let w = min(view.bounds.width - 36, 430)
        panel.frame = CGRect(x: (view.bounds.width - w) / 2, y: view.safeAreaInsets.top + 50, width: w, height: 56)
        let l = gameLabel(text, size: 13, alignment: .center); l.numberOfLines = 2
        l.frame = panel.bounds.insetBy(dx: 12, dy: 6); panel.addSubview(l)
        panel.isUserInteractionEnabled = false
        view.addSubview(panel); toastView = panel
        UIAccessibility.post(notification: .announcement, argument: text)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self, weak panel] in
            guard let self = self, generation == self.toastGeneration else { return }
            UIView.animate(withDuration: 0.18, animations: { panel?.alpha = 0 }) { _ in panel?.removeFromSuperview() }
        }
    }
}

final class CardDetailController: UIViewController {
    let kind: CardKind
    let owned: Bool
    private let panel = GamePanel(color: UIColor(hex: 0x18266E))
    init(kind: CardKind, owned: Bool) { self.kind = kind; self.owned = owned; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.76)
        panel.backgroundColor = UIColor(hex: 0x18266E)
        view.addSubview(panel)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        panel.subviews.forEach { $0.removeFromSuperview() }
        let w = min(view.bounds.width - 38, 350), h = min(view.bounds.height - 100, 564)
        panel.frame = CGRect(x: (view.bounds.width - w) / 2, y: (view.bounds.height - h) / 2, width: w, height: h)
        let cardH = min(230, h * 0.42), cardW = cardH / 1.48
        let card = CardView(kind); card.frame = CGRect(x: (w - cardW) / 2, y: 25, width: cardW, height: cardH)
        card.isUserInteractionEnabled = false
        card.accessibilityTraits = .image
        card.accessibilityHint = nil
        panel.addSubview(card)
        let name = gameLabel(kind.name + (owned ? "" : " · 未解锁"), size: 24, color: kind.tint, alignment: .center)
        name.frame = CGRect(x: 16, y: cardH + 44, width: w - 32, height: 34); panel.addSubview(name)
        let description = gameLabel(kind.detail + (owned ? "" : "\n通关后可在奖励中选择这张卡。"), size: 14, color: UIColor(hex: 0xDCE6FF), weight: .medium)
        description.numberOfLines = 0
        description.frame = CGRect(x: 25, y: cardH + 84, width: w - 50, height: h - cardH - 167); panel.addSubview(description)
        let close = GameButton("知道了", primary: true); close.titleLabel?.font = Palette.font(20, .heavy)
        close.frame = CGRect(x: 24, y: h - 67, width: w - 48, height: 47)
        close.onTap = { [weak self] in self?.dismiss(animated: true) }; panel.addSubview(close)
    }
}
