import UIKit
import SafariServices

final class ViewController: UIViewController, UIGestureRecognizerDelegate {
    private enum Screen { case lobby, deck, library, battle, reward, level, settings, contracts }
    private let store = GameStore()
    private let backdrop = GameBackdrop()
    private let scroll = UIScrollView()
    private let content = UIView()
    private var navigation = UIView()
    private var screen: Screen = .lobby
    private var levelPage = 0
    private var contractStake = 25
    private var contractRisk: ContractRisk = .measured
    private var levelPageSize: Int { view.bounds.height - view.safeAreaInsets.top - view.safeAreaInsets.bottom < 700 ? 2 : 3 }
    private var selectedCard: CardKind?
    private var selectedReward: CardKind?
    private var draftDeck: [CardKind]?
    private var selectedDeckSlot: Int?
    private var deckMessage: String?
    private var libraryIndex = 0
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
        if store.state.activeBattle?.outcome == .won {
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
        if destination == .deck { draftDeck = store.state.deck; selectedDeckSlot = nil; deckMessage = nil }
        screen = destination
        feedback()
        redraw()
        scroll.setContentOffset(.zero, animated: false)
    }
    private func redraw(preserveScroll: Bool = false) {
        let offset = scroll.contentOffset
        scroll.showsVerticalScrollIndicator = screen == .contracts || screen == .reward
        backdrop.frame = view.bounds
        let hasNav = screen == .lobby || screen == .deck || screen == .library || screen == .contracts
        let navHeight: CGFloat = hasNav ? 72 : 0
        scroll.frame = CGRect(x: 0, y: view.safeAreaInsets.top + 2, width: view.bounds.width,
                              height: view.bounds.height - view.safeAreaInsets.top - view.safeAreaInsets.bottom - navHeight - 2)
        content.subviews.forEach { $0.removeFromSuperview() }
        lanes.removeAll()
        navigation.removeFromSuperview()
        content.frame = CGRect(x: (view.bounds.width - width) / 2, y: 0, width: width, height: 0)
        let height: CGFloat
        switch screen {
        case .contracts: height = buildContracts()
        case .settings: height = buildSettings()
        case .level: height = buildLevels()
        case .lobby: height = buildLobby()
        case .deck: height = buildDeckWorkshop()
        case .library: height = buildLibrary()
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
        if text.contains("🪙") {
            l.attributedText = GoldCoin.text(text, font: l.font, color: color)
            l.accessibilityLabel = text.replacingOccurrences(of: "🪙", with: "Gold")
        }
        l.frame = frame; (parent ?? content).addSubview(l); return l
    }
    @discardableResult private func button(_ title: String, _ frame: CGRect, primary: Bool = false,
                                          icon: String? = nil, parent: UIView? = nil, action: @escaping () -> Void) -> GameButton {
        let b = GameButton(title, primary: primary, symbol: icon); b.frame = frame; b.onTap = action
        if title.contains("🪙"), let font = b.titleLabel?.font {
            b.setAttributedTitle(GoldCoin.text(title, font: font, color: primary ? Palette.ink : .white), for: .normal)
            b.accessibilityLabel = title.replacingOccurrences(of: "🪙", with: "Gold")
        }
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
        title("Time Cards", frame: CGRect(x: 22, y: 3, width: width - 90, height: compact ? 51 : 68), size: compact ? 43 : 51)
        button("", CGRect(x: width - 60, y: compact ? 9 : 17, width: 42, height: 42), icon: "gearshape.fill") { [weak self] in self?.showSettings() }.accessibilityLabel = "Settings"
        let stageIndex = store.state.selectedStage
        let stage = Stage.all[stageIndex]
        let level = button("Levels · \(store.state.viewingHard ? "Hard" : "Normal")  ⌄", CGRect(x: 56, y: compact ? 61 : 79, width: width - 112, height: 33)) { [weak self] in self?.chooseStage() }
        level.accessibilityIdentifier = "chooseLevels"
        level.titleLabel?.font = Palette.font(14, .heavy)
        let cardW = (inner - 40) / 3
        let cardH = cardW * (compact ? 1.38 : 1.45)
        let bannerY: CGFloat = compact ? 103 : 128
        let contractButton = button("Fate Contracts  ·  🪙 \(store.state.chips)", CGRect(x: 18, y: bannerY, width: inner - 4, height: 48), primary: true) { [weak self] in self?.show(.contracts) }
        contractButton.accessibilityIdentifier = "openContracts"
        let panelY = bannerY + 62
        let panelH = cardH * 2 + (compact ? 57 : 67)
        let panel = GamePanel(); panel.frame = CGRect(x: 16, y: panelY, width: inner, height: panelH); content.addSubview(panel)
        label("My Deck", CGRect(x: 14, y: 10, width: 150, height: 26), size: 20, parent: panel, weight: .heavy)
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
        _ = art(9 + stageIndex, CGRect(x: 5, y: 5, width: compact ? 50 : 60, height: compact ? 50 : 60), parent: challenge)
        label("\(store.state.viewingHard ? "Hard Mode" : "Adventure")  ·  Cleared \(store.state.viewingHard ? store.state.currentStars.count : store.state.completedStages.count)/\(Stage.all.count)", CGRect(x: 77, y: 9, width: inner - 106, height: 19), size: 11, color: Palette.quiet, parent: challenge)
        label(stage.name, CGRect(x: 77, y: compact ? 26 : 31, width: inner - 103, height: 29), size: 23, parent: challenge, weight: .heavy)
        let choose = UIButton(frame: challenge.bounds); choose.accessibilityLabel = "Levels"
        choose.addTarget(self, action: #selector(stageButtonTapped), for: .touchUpInside); challenge.addSubview(choose)
        label("›", CGRect(x: inner - 29, y: 22, width: 20, height: 30), size: 28, parent: challenge)
        let battle = store.state.activeBattle
        let startText = store.state.contract != nil ? "Resume Contract" : battle == nil ? "Start Battle" : (battle?.outcome == .won ? "Claim Reward" : battle?.outcome == .lost ? "Replay" : "Resume")
        let start = button(startText, CGRect(x: 18, y: challengeY + (compact ? 72 : 86), width: inner - 4, height: compact ? 50 : 58), primary: true, icon: "bolt.shield.fill") { [weak self] in self?.startOrResume() }
        start.accessibilityIdentifier = "startBattle"
        return challengeY + (compact ? 126 : 160)
    }
    @objc private func stageButtonTapped() { chooseStage() }

    private func buildNavigation() {
        navigation = UIView(frame: CGRect(x: (view.bounds.width - width) / 2, y: view.bounds.height - view.safeAreaInsets.bottom - 68, width: width, height: 68 + view.safeAreaInsets.bottom))
        navigation.backgroundColor = UIColor(hex: 0x0D164F)
        let line = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 1)); line.backgroundColor = UIColor(hex: 0x4459A7); navigation.addSubview(line)
        let titles = ["Adventure", "Contracts", "Deck", "Collection"], icons = ["mountain.2.fill", "suit.spade.fill", "rectangle.on.rectangle.angled", "book.closed.fill"]
        let pages: [Screen] = [.lobby, .contracts, .deck, .library]
        for i in 0..<4 {
            let tab = UIButton(frame: CGRect(x: CGFloat(i) * width / 4, y: 1, width: width / 4, height: 67))
            let active = screen == pages[i]
            if active {
                tab.backgroundColor = UIColor(hex: 0x213C9A)
                let glow = UIView(frame: CGRect(x: 23, y: 0, width: width / 4 - 46, height: 3)); glow.backgroundColor = Palette.cyan; tab.addSubview(glow)
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
    @objc private func tabTapped(_ sender: UIButton) {
        let destination: Screen = [.lobby, .contracts, .deck, .library][sender.tag]
        guard destination != screen else { return }
        if screen == .deck, let draft = draftDeck, draft != store.state.deck {
            let alert = UIAlertController(title: "Unsaved Deck", message: "Your saved deck will take effect in your next battle.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Save & Continue", style: .default) { [weak self] _ in
                guard let self = self else { return }
                self.store.state.deck = draft; self.store.save(); self.show(destination)
            })
            alert.addAction(UIAlertAction(title: "Discard Changes", style: .destructive) { [weak self] _ in self?.show(destination) })
            alert.addAction(UIAlertAction(title: "Keep Editing", style: .cancel))
            present(alert, animated: true)
        } else { show(destination) }
    }

    private func buildDeckWorkshop() -> CGFloat {
        let compact = scroll.bounds.height < 650
        let current = draftDeck ?? store.state.deck
        let units = current.filter { $0.isUnit }.count
        let average = Double(current.reduce(0) { $0 + $1.cost }) / Double(max(1, current.count))
        title("Deck Builder", frame: CGRect(x: 16, y: 3, width: inner, height: 46), size: 33)
        label("6 cards · Avg. \(String(format: "%.1f", average)) · \(units) units / \(6 - units) spells", CGRect(x: 16, y: 53, width: inner, height: 22), size: 13, color: Palette.cyan, align: .center)
        label("1. Pick a slot    2. Choose a reserve    3. Save", CGRect(x: 16, y: 77, width: inner, height: 18), size: 11, color: Palette.quiet, align: .center)
        let cardW: CGFloat = compact ? 82 : 96
        let cardH = cardW * 1.38
        let gridWidth = cardW * 3 + 24
        let gridX = (width - gridWidth) / 2
        let gridY: CGFloat = 105
        for (i, kind) in current.enumerated() {
            let card = CardView(kind)
            card.frame = CGRect(x: gridX + CGFloat(i % 3) * (cardW + 12), y: gridY + CGFloat(i / 3) * (cardH + 10), width: cardW, height: cardH)
            card.selectedCard = selectedDeckSlot == i
            card.accessibilityIdentifier = "deck.slot.\(i)"
            card.accessibilityHint = "Tap to choose a card to replace. Hold for details."
            card.onTap = { [weak self] in
                self?.selectedDeckSlot = i; self?.deckMessage = nil; self?.feedback(); self?.redraw()
            }
            addDetailsGesture(card); content.addSubview(card)
        }
        let gridBottom = gridY + cardH * 2 + 10
        let hint = deckMessage ?? selectedDeckSlot.map { "Replace \(current[$0].name) · Pick a reserve" } ?? "Your reserves · Select a card above first"
        label(hint, CGRect(x: 16, y: gridBottom + 9, width: inner, height: 22), size: 12, color: Palette.yellow, align: .center)
        let candidates = store.state.collection.filter { !current.contains($0) }
        let candidateY = gridBottom + 39
        let candidateW: CGFloat = compact ? 68 : 78
        let candidateH = candidateW * 1.38
        if candidates.isEmpty {
            let panel = GamePanel(); panel.frame = CGRect(x: 24, y: candidateY, width: width - 48, height: candidateH); content.addSubview(panel)
            let empty = label("No reserve cards yet\nEarn cards on Normal levels 2, 4 and 6.", CGRect(x: 12, y: 12, width: width - 72, height: candidateH - 24), size: 14, color: Palette.quiet, align: .center, parent: panel)
            empty.numberOfLines = 2
        } else {
            let rowWidth = CGFloat(candidates.count) * candidateW + CGFloat(candidates.count - 1) * 18
            for (i, kind) in candidates.enumerated() {
                let card = CardView(kind)
                card.frame = CGRect(x: (width - rowWidth) / 2 + CGFloat(i) * (candidateW + 18), y: candidateY, width: candidateW, height: candidateH)
                card.accessibilityIdentifier = "deck.replace.\(kind.rawValue)"
                card.accessibilityHint = "Replace the selected deck card. Hold for details."
                card.onTap = { [weak self] in self?.replaceDeckCard(with: kind) }
                addDetailsGesture(card); content.addSubview(card)
            }
        }
        let saveY = candidateY + candidateH + 14
        let dirty = current != store.state.deck
        let reset = button("Reset", CGRect(x: 16, y: saveY, width: 72, height: 45)) { [weak self] in
            guard let self = self else { return }
            self.draftDeck = self.store.state.deck; self.selectedDeckSlot = nil; self.deckMessage = nil; self.redraw()
        }
        reset.isEnabled = dirty; reset.alpha = dirty ? 1 : 0.45; reset.accessibilityIdentifier = "deck.reset"
        let save = button(dirty ? "Save Deck" : "Deck Saved", CGRect(x: 100, y: saveY, width: width - 116, height: 45), primary: true) { [weak self] in
            guard let self = self, let deck = self.draftDeck, deck.count == 6, Set(deck).count == 6,
                  deck.allSatisfy({ self.store.state.collection.contains($0) }) else { return }
            self.store.state.deck = deck; self.store.save(); self.deckMessage = "Saved · Applies to your next battle"; self.redraw()
        }
        save.isEnabled = dirty; save.alpha = dirty ? 1 : 0.6; save.accessibilityIdentifier = "saveDeck"
        return saveY + 57
    }
    private func replaceDeckCard(with kind: CardKind) {
        guard var draft = draftDeck, let slot = selectedDeckSlot, draft.indices.contains(slot) else {
            toast("Select a card above to replace first."); return
        }
        guard store.state.collection.contains(kind), !draft.contains(kind) else { return }
        let old = draft[slot]
        draft[slot] = kind; draftDeck = draft
        deckMessage = "\(old.name) → \(kind.name) · Unsaved"
        feedback(); redraw()
    }

    private func buildLibrary() -> CGFloat {
        let compact = scroll.bounds.height < 650
        let cards = CardKind.allCases
        libraryIndex = min(max(libraryIndex, 0), cards.count - 1)
        let kind = cards[libraryIndex]
        let owned = store.state.collection.contains(kind)
        title("Card Collection", frame: CGRect(x: 16, y: 3, width: inner, height: 46), size: 33)
        label("Collected \(store.state.collection.count)/\(cards.count) · Card \(libraryIndex + 1)", CGRect(x: 16, y: 55, width: inner, height: 22), size: 14, color: Palette.yellow, align: .center)
        let progress = UIProgressView(progressViewStyle: .default)
        progress.frame = CGRect(x: 36, y: 87, width: width - 72, height: 5)
        progress.progressTintColor = Palette.yellow; progress.trackTintColor = UIColor(hex: 0x354681)
        progress.progress = Float(store.state.collection.count) / Float(cards.count)
        progress.accessibilityLabel = "Card collection progress"; content.addSubview(progress)
        let heroY: CGFloat = 106
        let cardW: CGFloat = compact ? 116 : 145
        let cardH = cardW * 1.4
        let card = CardView(kind)
        card.frame = CGRect(x: 22, y: heroY, width: cardW, height: cardH)
        card.onTap = { [weak self] in self?.showCardDetail(kind) }
        card.accessibilityIdentifier = "library.featured"
        content.addSubview(card)
        let infoX = card.frame.maxX + 17, infoW = width - infoX - 22
        label(kind.name, CGRect(x: infoX, y: heroY + 3, width: infoW, height: 30), size: 22, color: kind.tint, weight: .heavy)
        label("\(kind.isUnit ? "Unit" : "Spell") · \(kind.cost) energy", CGRect(x: infoX, y: heroY + 39, width: infoW, height: 22), size: 13, color: Palette.quiet)
        label(owned ? "✓ Collected" : "🔒 Locked", CGRect(x: infoX, y: heroY + 69, width: infoW, height: 23), size: 15, color: owned ? Palette.green : Palette.yellow)
        let acquisition = label(kind.acquisition, CGRect(x: infoX, y: heroY + 100, width: infoW, height: cardH - 98), size: 12, color: Palette.quiet, weight: .medium)
        acquisition.numberOfLines = 0
        let detailY = heroY + cardH + 14
        label("Card Effect", CGRect(x: 22, y: detailY, width: inner, height: 21), size: 14, color: Palette.cyan)
        let description = label(kind.detail, CGRect(x: 22, y: detailY + 24, width: width - 44, height: compact ? 57 : 65), size: 12, weight: .medium)
        description.numberOfLines = 0
        let tipY = detailY + (compact ? 87 : 95)
        let tip = GamePanel(color: UIColor(hex: 0x49347B)); tip.frame = CGRect(x: 16, y: tipY, width: inner, height: 82); content.addSubview(tip)
        label("Deck Tip", CGRect(x: 12, y: 7, width: inner - 24, height: 20), size: 13, color: Palette.yellow, parent: tip)
        let pairing = label(kind.pairingTip, CGRect(x: 12, y: 29, width: inner - 24, height: 46), size: 12, parent: tip, weight: .medium)
        pairing.numberOfLines = 3
        let shelfY = tipY + 95
        let thumbW = min(40, (inner - 32) / CGFloat(cards.count))
        let shelfW = CGFloat(cards.count) * thumbW + CGFloat(cards.count - 1) * 4
        for (i, item) in cards.enumerated() {
            let thumb = UIButton(frame: CGRect(x: (width - shelfW) / 2 + CGFloat(i) * (thumbW + 4), y: shelfY, width: thumbW, height: 40))
            thumb.setImage(GameArt.image(item.art), for: .normal); thumb.imageView?.contentMode = .scaleAspectFill
            thumb.layer.cornerRadius = 8; thumb.clipsToBounds = true
            thumb.layer.borderWidth = i == libraryIndex ? 3 : 1
            thumb.layer.borderColor = (i == libraryIndex ? Palette.yellow : Palette.quiet).cgColor
            thumb.alpha = store.state.collection.contains(item) ? 1 : 0.48
            thumb.tag = i; thumb.addTarget(self, action: #selector(libraryCardTapped(_:)), for: .touchUpInside)
            thumb.accessibilityLabel = "\(item.name), \(store.state.collection.contains(item) ? "Collected" : "Locked")"
            thumb.accessibilityIdentifier = "library.\(item.rawValue)"
            content.addSubview(thumb)
        }
        let footerY = shelfY + 52
        let previous = button("Previous", CGRect(x: 16, y: footerY, width: 103, height: 40)) { [weak self] in self?.moveLibrary(-1) }
        previous.isEnabled = libraryIndex > 0; previous.alpha = previous.isEnabled ? 1 : 0.4
        previous.titleLabel?.font = Palette.font(14, .bold)
        previous.accessibilityIdentifier = "library.previous"
        label("Tap to browse", CGRect(x: 123, y: footerY + 8, width: width - 246, height: 22), size: 10, color: Palette.quiet, align: .center)
        let next = button("Next", CGRect(x: width - 119, y: footerY, width: 103, height: 40)) { [weak self] in self?.moveLibrary(1) }
        next.isEnabled = libraryIndex + 1 < cards.count; next.alpha = next.isEnabled ? 1 : 0.4
        next.titleLabel?.font = Palette.font(14, .bold)
        next.accessibilityIdentifier = "library.next"
        return footerY + 52
    }
    @objc private func libraryCardTapped(_ sender: UIButton) {
        libraryIndex = sender.tag; feedback(); redraw()
    }
    private func moveLibrary(_ offset: Int) {
        libraryIndex = min(max(libraryIndex + offset, 0), CardKind.allCases.count - 1)
        feedback(); redraw()
    }

    private func buildBattle() -> CGFloat {
        guard let battle = store.state.activeBattle else { screen = .lobby; return buildLobby() }
        let compact = scroll.bounds.height < (store.state.contract == nil ? 710 : 820)
        let contract = store.state.contract
        let smallContract = contract != nil && scroll.bounds.height < 680
        let enemyY: CGFloat = (compact ? 52 : 64) + (contract == nil ? 0 : 67)
        let enemyH: CGFloat = compact ? 94 : 120
        let laneY = enemyY + enemyH + 14
        button("", CGRect(x: 16, y: 5, width: 42, height: 40), icon: "chevron.left") { [weak self] in self?.leaveBattle() }.accessibilityLabel = "Back to Lobby"
        label(battle.stage.name, CGRect(x: 64, y: 4, width: width - 128, height: 27), size: 20, align: .center, weight: .heavy)
        label("\(battle.isHard ? "Hard · " : "")\(battle.stage.lesson) · Info ⓘ", CGRect(x: 64, y: 32, width: width - 128, height: 18), size: 11, color: Palette.quiet, align: .center)
        button("", CGRect(x: width - 58, y: 5, width: 42, height: 40), icon: "questionmark") { [weak self] in self?.showRules() }.accessibilityLabel = "How to Play"
        let info = UIButton(frame: CGRect(x: 64, y: 29, width: width - 128, height: 23))
        info.accessibilityLabel = "Level rules and challenges"; info.accessibilityIdentifier = "encounterInfo"
        info.addTarget(self, action: #selector(showEncounterInfo), for: .touchUpInside); content.addSubview(info)
        if let contract {
            label("♠ \(contract.risk.name) · Round \(contract.round + 1)/3 · Stake \(contract.stake)", CGRect(x: 18, y: 55, width: inner, height: 22), size: 13, color: Palette.yellow)
            label("Win: \(contract.payout) gold · Lose: 0", CGRect(x: 18, y: 81, width: inner - 148, height: 26), size: 11, color: Palette.quiet)
            let boost = button("−3 HP / +2 ϟ", CGRect(x: width - 158, y: 79, width: 140, height: 30)) { [weak self] in
                guard let self = self, var current = self.store.state.activeBattle, !self.settlingTurn, current.overdrive() else { return }
                self.store.state.activeBattle = current; self.store.save(); self.feedback(.medium); self.redraw(preserveScroll: true)
            }
            boost.titleLabel?.font = Palette.font(12)
            boost.isEnabled = battle.outcome == .playing && battle.playerHealth > 3 && battle.energy <= 3 && battle.overdriveTurn != battle.turn && !settlingTurn
            boost.accessibilityIdentifier = "contract.overdrive"
            boost.accessibilityLabel = "Overdrive: spend 3 health to gain 2 energy, once per turn"
        }
        let enemy = GamePanel(color: UIColor(hex: 0x253991)); enemy.frame = CGRect(x: 16, y: enemyY, width: inner, height: enemyH); content.addSubview(enemy)
        _ = art(9 + battle.stageIndex, CGRect(x: 7, y: 7, width: enemyH - 14, height: enemyH - 14), parent: enemy, radius: 14)
        label(battle.stage.enemy, CGRect(x: enemyH + 9, y: compact ? 6 : 11, width: inner - enemyH - 23, height: 26), size: 21, parent: enemy, weight: .heavy)
        let bar = HealthBar(current: battle.enemyHealth, maximum: battle.stage.health)
        bar.frame = CGRect(x: enemyH + 8, y: compact ? 34 : 44, width: inner - enemyH - 23, height: 23); enemy.addSubview(bar)
        let intent = label(battle.enemyStatus, CGRect(x: enemyH + 8, y: compact ? 62 : 76, width: inner - enemyH - 23, height: compact ? 25 : 33), size: 12, color: UIColor(hex: 0xFFF0C1), align: .center, parent: enemy, weight: .heavy)
        intent.backgroundColor = UIColor(hex: 0xB2365D); intent.layer.cornerRadius = 10; intent.clipsToBounds = true
        let laneW = (inner - 16) / 3
        let laneH = smallContract ? 140 : compact ? min(180, laneW * 1.35 + 57) : laneW * 1.35 + 57
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
        label("Turn \(battle.turn)", CGRect(x: inner * 0.74, y: 8, width: inner * 0.23, height: 25), size: 12, color: .white, align: .right, parent: hud)
        let hintY = hudY + (compact ? 47 : 51)
        let hintText = selectedCard.map { "\($0.name) · Tap a glowing slot" } ?? "Tap or drag a card into a time slot"
        label(hintText, CGRect(x: 16, y: hintY, width: inner, height: 22), size: 12, color: selectedCard == nil ? Palette.quiet : Palette.yellow, align: .center)
        let handY = hintY + (compact ? 31 : 41)
        let cardW: CGFloat = min(smallContract ? 88 : 112, inner * 0.295), cardH = cardW * (compact ? 1.30 : 1.42)
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
            label("No cards left. End your turn to draw.", CGRect(x: 25, y: handY + 52, width: width - 50, height: 45), size: 15, color: Palette.quiet, align: .center)
        }
        let footerY = handY + cardH + (compact ? 16 : 22)
        button("Log", CGRect(x: 16, y: footerY + 5, width: 107, height: 44), icon: "list.bullet") { [weak self] in self?.showBattleLog() }.accessibilityIdentifier = "battleLog"
        let end = button("End Turn", CGRect(x: width - 185, y: footerY, width: 169, height: 53), primary: true) { [weak self] in self?.endTurn() }
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
            if let field = store.state.activeBattle?.field[lane.rawValue] { showCardDetail(field.kind) }
            else { toast(lane.hint + " · Select a card first") }
            return
        }
        play(card, in: lane)
    }
    private func play(_ card: CardKind, in lane: TimeLane) {
        guard var battle = store.state.activeBattle, !settlingTurn else { return }
        if let error = battle.play(card, in: lane) { toast(error); return }
        store.state.activeBattle = battle; store.save(); selectedCard = nil
        feedback(.medium)
        if battle.outcome == .won { showVictory(); return }
        redraw(preserveScroll: true)
        if !store.state.reducedMotion && !UIAccessibility.isReduceMotionEnabled,
           let target = lanes.first(where: { $0.lane == lane }) {
            target.transform = CGAffineTransform(scaleX: 0.93, y: 0.93)
            UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.7, options: []) { target.transform = .identity }
        }
        toast(battle.log.last ?? "Card played")
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
            for lane in lanes { lane.accepting = store.state.activeBattle?.canPlay(source.kind, in: lane.lane) == nil }
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
        return store.state.activeBattle?.outcome == .playing && !settlingTurn
    }
    private func endTurn() {
        guard var battle = store.state.activeBattle, !settlingTurn, battle.outcome == .playing else { return }
        toastView?.removeFromSuperview()
        toastGeneration += 1
        battle.endTurn(); store.state.activeBattle = battle; store.save(); selectedCard = nil
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
                if battle.outcome == .playing { self.toast("Turn \(battle.turn) · Energy restored") }
            }
        }
    }
    private func showVictory() {
        selectedReward = store.state.rewards.count > 1 ? store.state.rewards[1] : store.state.rewards.first
        show(.reward)
        if store.state.haptics { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    }

    private func buildReward() -> CGFloat {
        if store.state.contract != nil { return buildContractResult() }
        guard let battle = store.state.activeBattle, battle.outcome == .won else { screen = .lobby; return buildLobby() }
        let choices = store.state.rewards
        if choices.isEmpty { return buildClearSummary(battle) }
        let star = UILabel(frame: CGRect(x: 16, y: 6, width: inner, height: 41)); star.text = String(repeating: "★ ", count: battle.stars) + String(repeating: "☆ ", count: 3 - battle.stars)
        star.font = Palette.font(31, .black); star.textColor = Palette.yellow; star.textAlignment = .center; content.addSubview(star)
        title(battle.stageIndex == Stage.all.count - 1 ? "All Clear!" : "Victory!", frame: CGRect(x: 20, y: 48, width: width - 40, height: 86), size: battle.stageIndex == Stage.all.count - 1 ? 48 : 71)
        label(choices.isEmpty ? "Collection complete. Set a new record!" : "Choose a new card", CGRect(x: 36, y: 139, width: width - 72, height: 34), size: 20, align: .center, weight: .heavy)
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
        label(selected.isUnit ? "Past: grow next turn" : selected.keyword, CGRect(x: 99, y: 44, width: inner - 120, height: 22), size: 13, parent: panel)
        label("\(selected.cost) energy · \(selected.isUnit ? "Unit" : "Spell")", CGRect(x: 99, y: 69, width: inner - 120, height: 17), size: 11, color: selected.tint, parent: panel)
        let results = label("Turn \(battle.turn) · HP \(battle.playerHealth) · Blocked \(battle.damageBlocked)\n\(battle.challengeMet ? "✓" : "○") \(battle.stage.challenge)", CGRect(x: 16, y: detailY + 104, width: inner, height: 46), size: 13, color: Palette.quiet, align: .center)
        results.numberOfLines = 2
        let claim = button(choices.isEmpty ? "Finish" : "Add to Deck", CGRect(x: 18, y: detailY + 161, width: inner - 4, height: 58), primary: true) { [weak self] in self?.claimReward() }
        claim.accessibilityIdentifier = "claimReward"
        button("Card Details", CGRect(x: 80, y: detailY + 235, width: width - 160, height: 41)) { [weak self] in self?.showCardDetail(selected) }
        return detailY + 296
    }
    private func claimReward() {
        guard store.state.activeBattle?.outcome == .won else { return }
        let choices = store.state.rewards
        if choices.isEmpty { completeReward(nil, replacing: nil); return }
        guard let selected = selectedReward, choices.contains(selected) else { toast("Select a reward card first."); return }
        let sheet = UIAlertController(title: "Add \(selected.name)", message: "Your deck holds 6 cards. Choose one to replace. The old card stays in your collection.", preferredStyle: .actionSheet)
        for kind in store.state.deck {
            sheet.addAction(UIAlertAction(title: "Replace \(kind.name)", style: .default) { [weak self] _ in self?.completeReward(selected, replacing: kind) })
        }
        sheet.addAction(UIAlertAction(title: "Collect Only", style: .default) { [weak self] _ in self?.completeReward(selected, replacing: nil) })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        presentSheet(sheet)
    }
    private func completeReward(_ reward: CardKind?, replacing old: CardKind?) {
        let completedFinal = store.state.activeBattle?.stageIndex == Stage.all.count - 1
        guard store.state.claimVictory(reward) else { return }
        if let reward = reward, let old = old, let i = store.state.deck.firstIndex(of: old) { store.state.deck[i] = reward }
        store.save()
        if completedFinal { chooseStage() } else { show(.lobby) }
        toast(reward.map { "\($0.name) unlocked!" } ?? (store.state.hardUnlocked ? "Stars saved! Change difficulty in Levels." : "Clear recorded!"))
    }

    private func startOrResume() {
        if let run = store.state.contract {
            show(run.battle.outcome == .won ? .reward : run.battle.outcome == .lost ? .contracts : .battle); return
        }
        if store.state.activeBattle?.outcome == .won { showVictory(); return }
        let isNewBattle = store.state.activeBattle == nil || store.state.activeBattle?.outcome == .lost
        if isNewBattle { store.state.startBattle(); store.save() }
        show(.battle)
        if !store.state.hasSeenRules {
            store.state.hasSeenRules = true; store.save()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in self?.showRules() }
        } else if isNewBattle {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in self?.showEncounterInfo() }
        }
    }
    private func leaveBattle() {
        if store.state.contract != nil { store.save(); show(.contracts); return }
        if store.state.activeBattle?.outcome == .lost { store.state.activeBattle = nil }
        store.save(); show(.lobby)
        toast("Battle saved. Resume any time.")
    }
    private func chooseStage() {
        guard store.state.contract == nil else { show(.contracts); toast("Finish your contract to return to Adventure."); return }
        levelPage = store.state.selectedStage / levelPageSize; show(.level) }

    private func buildLevels() -> CGFloat {
        button("Back", CGRect(x: 16, y: 8, width: 62, height: 38)) { [weak self] in self?.show(.lobby) }
        title("Levels", frame: CGRect(x: 80, y: 4, width: width - 160, height: 45), size: 30)
        let total = store.state.currentStars.values.reduce(0, +)
        label("\(store.state.viewingHard ? "Hard" : "Normal") · \(store.state.viewingHard ? store.state.currentStars.count : store.state.completedStages.count)/6 cleared · ★ \(total)/18", CGRect(x: 16, y: 61, width: inner, height: 25), size: 16, color: Palette.yellow, align: .center)
        let mode = button(store.state.hardUnlocked ? (store.state.viewingHard ? "Normal · View Stars" : "Hard · New Rules") : "Hard unlocks after all 6 levels", CGRect(x: 58, y: 89, width: width - 116, height: 25)) { [weak self] in self?.switchDifficulty() }
        mode.titleLabel?.font = Palette.font(12, .bold)
        mode.accessibilityIdentifier = "difficultySwitch"
        let pageCount = (Stage.all.count + levelPageSize - 1) / levelPageSize
        levelPage = min(levelPage, pageCount - 1)
        let previous = button("Previous", CGRect(x: 16, y: 119, width: 85, height: 31)) { [weak self] in
            guard let self = self else { return }; self.levelPage -= 1; self.redraw()
        }
        previous.isEnabled = levelPage > 0; previous.alpha = previous.isEnabled ? 1 : 0.4
        previous.titleLabel?.font = Palette.font(14, .bold)
        previous.accessibilityIdentifier = "level.previous"
        label("Levels \(levelPage * levelPageSize + 1)–\(min(Stage.all.count, (levelPage + 1) * levelPageSize)) / 6", CGRect(x: 104, y: 122, width: width - 208, height: 23), size: 14, align: .center)
        let next = button("Next", CGRect(x: width - 101, y: 119, width: 85, height: 31)) { [weak self] in
            guard let self = self else { return }; self.levelPage += 1; self.redraw()
        }
        next.isEnabled = levelPage + 1 < pageCount; next.alpha = next.isEnabled ? 1 : 0.4
        next.titleLabel?.font = Palette.font(14, .bold)
        next.accessibilityIdentifier = "level.next"
        let start = levelPage * levelPageSize
        for i in start..<min(Stage.all.count, start + levelPageSize) {
            let stage = Stage.all[i]
            let unlocked = i <= store.state.unlockedStage
            let y = CGFloat(i - start) * 197 + 163
            let colors: [UInt32] = [0x20377F, 0x215B54, 0x523D88, 0x773954, 0x205B77, 0x653370]
            let panel = GamePanel(color: UIColor(hex: colors[i]))
            panel.frame = CGRect(x: 16, y: y, width: inner, height: 182); content.addSubview(panel)
            _ = art(9 + i, CGRect(x: 10, y: 12, width: 40, height: 45), parent: panel, radius: 9)
            label(stage.name, CGRect(x: 58, y: 10, width: inner - 70, height: 29), size: 21, parent: panel, weight: .heavy)
            let score = store.state.currentStars[String(i)] ?? 0
            label("\(stage.lesson)  ·  \(String(repeating: "★", count: score))\(String(repeating: "☆", count: 3 - score))", CGRect(x: 58, y: 41, width: inner - 70, height: 20), size: 12, color: Palette.yellow, parent: panel)
            let rule = label(store.state.viewingHard ? stage.hardModifier : stage.briefing, CGRect(x: 14, y: 69, width: inner - 28, height: 46), size: 12, color: Palette.quiet, parent: panel)
            rule.numberOfLines = 3
            label("Goal: \(stage.challenge)", CGRect(x: 14, y: 118, width: inner - 28, height: 20), size: 12, parent: panel)
            let status = store.state.viewingHard ? "Separate stars" : (store.state.completedStages.contains(i) ? "Cleared · Earn more stars" : (stage.rewardMilestone ? "First clear: new card" : "Unlock the next level"))
            label(status, CGRect(x: 14, y: 149, width: inner - 158, height: 20), size: 12, color: Palette.cyan, parent: panel)
            let select = button(unlocked ? (store.state.currentStars[String(i)] != nil ? "Replay" : "Select") : "Locked", CGRect(x: inner - 138, y: 139, width: 124, height: 34), primary: unlocked, parent: panel) { [weak self] in
                self?.requestStage(i)
            }
            select.isEnabled = unlocked; select.alpha = unlocked ? 1 : 0.45
            select.accessibilityIdentifier = "stage.\(i)"
        }
        return 165 + CGFloat(levelPageSize) * 197
    }
    private func switchDifficulty() {
        guard store.state.hardUnlocked else {
            let alert = UIAlertController(title: "Hard Mode Locked", message: "Clear all 6 Normal levels to unlock Hard mode. Each level adds a new rule. Stars are tracked separately.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Continue", style: .default)); present(alert, animated: true); return
        }
        let change = { [weak self] in
            guard let self = self else { return }
            self.store.state.selectedHard = !self.store.state.viewingHard
            self.store.state.activeBattle = nil
            self.store.save(); self.redraw()
        }
        if store.state.activeBattle != nil {
            let alert = UIAlertController(title: "Change Difficulty?", message: "Your current battle will end. Collected cards and stars in both difficulties are kept.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Keep Battle", style: .cancel))
            alert.addAction(UIAlertAction(title: "Change Difficulty", style: .destructive) { _ in change() })
            present(alert, animated: true)
        } else { change() }
    }
    private func requestStage(_ index: Int) {
        guard index <= store.state.unlockedStage else { return }
        if store.state.activeBattle != nil {
            let confirm = UIAlertController(title: "Start a New Battle?", message: "This replaces your current battle. Collected cards and cleared levels are kept.", preferredStyle: .alert)
            confirm.addAction(UIAlertAction(title: "Keep Battle", style: .cancel))
            confirm.addAction(UIAlertAction(title: "Change Level", style: .destructive) { [weak self] _ in self?.selectStage(index) })
            present(confirm, animated: true)
        } else { selectStage(index) }
    }
    @objc private func showEncounterInfo() {
        guard let battle = store.state.activeBattle else { return }
        if store.state.contract != nil { showContractRules(); return }
        let text = "\(battle.briefing)\n\nGoal: defeat the enemy.\nStars: win; finish with at least 12 HP; \(battle.stage.challenge).\n\n\(battle.isHard ? "Hard stars are separate. No repeat card rewards." : battle.stageIndex == 5 ? "Clear all 6 Normal levels to unlock Hard mode." : battle.stage.rewardMilestone ? "Choose a new card on your first clear." : "Your first clear unlocks the next level.")"
        let alert = UIAlertController(title: battle.stage.name, message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Play", style: .default)); present(alert, animated: true)
    }
    private func buildClearSummary(_ battle: BattleState) -> CGFloat {
        let finished = battle.stageIndex == Stage.all.count - 1
        let compact = scroll.bounds.height < 700
        title(battle.isHard ? "Success!" : finished ? "All Clear!" : "Victory!", frame: CGRect(x: 20, y: compact ? 12 : 45, width: width - 40, height: 86), size: 52)
        label(String(repeating: "★ ", count: battle.stars) + String(repeating: "☆ ", count: 3 - battle.stars), CGRect(x: 16, y: compact ? 100 : 146, width: inner, height: 50), size: 38, color: Palette.yellow, align: .center)
        _ = art(9 + battle.stageIndex, CGRect(x: (width - 110) / 2, y: compact ? 165 : 222, width: 110, height: 110), radius: 25)
        label((battle.isHard ? "Hard · " : "") + battle.stage.name, CGRect(x: 16, y: compact ? 287 : 384, width: inner, height: 32), size: 23, align: .center)
        let results = "✓ Enemy defeated\n\(battle.playerHealth >= 12 ? "✓" : "○") 12+ HP · Finished with \(battle.playerHealth)\n\(battle.challengeMet ? "✓" : "○") \(battle.stage.challenge)\n\n\(battle.turn) turns · \(battle.damageBlocked) damage blocked"
        let stats = label(results, CGRect(x: 28, y: compact ? 330 : 433, width: width - 56, height: 146), size: 16, align: .center)
        stats.numberOfLines = 6
        let claim = button(finished ? (battle.isHard ? "View Hard Stars" : "Finish · Unlock Hard") : "Finish", CGRect(x: 20, y: compact ? 501 : 606, width: width - 40, height: 56), primary: true) { [weak self] in self?.claimReward() }
        claim.accessibilityIdentifier = "claimReward"
        return compact ? 582 : 690
    }
    private func selectStage(_ index: Int) {
        store.state.selectedStage = index; store.state.activeBattle = nil; store.save(); show(.lobby)
    }
    private func showDefeatOverlay(afterLayout: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.screen == .battle, self.store.state.activeBattle?.outcome == .lost, self.presentedViewController == nil else { return }
            if self.store.state.contract != nil { self.show(.contracts); return }
            let alert = UIAlertController(title: "Defeat", message: self.store.state.activeBattle?.briefing, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Retry", style: .default) { [weak self] _ in
                guard let self = self else { return }
                self.store.state.startBattle(); self.store.save(); self.redraw()
            })
            alert.addAction(UIAlertAction(title: "Edit Deck", style: .default) { [weak self] _ in
                self?.store.state.activeBattle = nil; self?.store.save(); self?.show(.deck)
            })
            alert.addAction(UIAlertAction(title: "Back to Lobby", style: .cancel) { [weak self] _ in self?.leaveBattle() })
            self.present(alert, animated: true)
        }
    }
    private func showRules() {
        if screen == .battle && store.state.contract != nil { showContractRules(); return }
        let message = "Defeat the enemy before you run out of HP.\n\nTap a card, then a time slot, or drag it there. Hold a card for details.\n\nPAST: units wait one turn, then gain +2 attack permanently.\nPRESENT: units attack this turn; spells act now.\nFUTURE: cards wait one turn, then double their first attack or spell effect.\n\nEnd Turn: your units attack, then the enemy attacks. If you survive, energy refills, waiting cards activate, and you draw 2 cards. Tap the level info for enemy rules.\n\nShield carries over. Maximum energy: 5. Hand limit: 6."
        let alert = UIAlertController(title: "Master the Timeline", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: screen == .settings ? "Got It" : "Play", style: .default))
        present(alert, animated: true)
    }
    private func showBattleLog() {
        let alert = UIAlertController(title: "Battle Log", message: store.state.activeBattle?.log.suffix(14).joined(separator: "\n\n").replacingOccurrences(of: " chips", with: " gold"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Resume", style: .default)); present(alert, animated: true)
    }
    private func showSettings() {
        show(.settings)
    }
    private func buildSettings() -> CGFloat {
        let back = button("Back", CGRect(x: 16, y: 8, width: 62, height: 38)) { [weak self] in self?.show(.lobby) }
        back.accessibilityIdentifier = "settings.back"
        title("Settings", frame: CGRect(x: 84, y: 4, width: width - 168, height: 48), size: 30)
        label("Make each battle feel right", CGRect(x: 16, y: 70, width: inner, height: 24), size: 14, color: Palette.quiet, align: .center)

        let options: [(String, String, Bool, Selector, String)] = [
            ("Haptics", "Gentle feedback for card plays", store.state.haptics, #selector(hapticsChanged(_:)), "settings.haptics"),
            ("Reduce Motion", "Less bounce and screen shake", store.state.reducedMotion, #selector(motionChanged(_:)), "settings.motion")
        ]
        for (index, option) in options.enumerated() {
            let panel = GamePanel(color: index == 0 ? UIColor(hex: 0x20377F) : UIColor(hex: 0x523D88))
            panel.frame = CGRect(x: 16, y: 120 + CGFloat(index) * 110, width: inner, height: 94)
            content.addSubview(panel)
            label(option.0, CGRect(x: 18, y: 17, width: inner - 102, height: 27), size: 21, parent: panel, weight: .heavy)
            label(option.1, CGRect(x: 18, y: 51, width: inner - 102, height: 24), size: 12, color: Palette.quiet, parent: panel)
            let toggle = UISwitch()
            toggle.frame.origin = CGPoint(x: inner - 71, y: 31)
            toggle.onTintColor = Palette.cyan
            toggle.isOn = option.2
            toggle.accessibilityLabel = option.0
            toggle.accessibilityHint = option.1
            toggle.accessibilityIdentifier = option.4
            toggle.addTarget(self, action: option.3, for: .valueChanged)
            panel.addSubview(toggle)
        }
        let help = button("How to Play", CGRect(x: 16, y: 348, width: inner, height: 58), icon: "questionmark.circle.fill") { [weak self] in self?.showRules() }
        help.accessibilityIdentifier = "settings.rules"
        let privacy = button("Privacy Policy", CGRect(x: 16, y: 418, width: inner, height: 58), icon: "hand.raised.fill") { [weak self] in self?.showPrivacyPolicy() }
        privacy.accessibilityIdentifier = "settings.privacy"
        let note = label("Settings save automatically\nDecks and progress stay on this device", CGRect(x: 24, y: 494, width: width - 48, height: 52), size: 13, color: Palette.quiet, align: .center)
        note.numberOfLines = 2
        return 568
    }
    private func showPrivacyPolicy() {
        guard let url = URL(string: "https://doc-hosting.flycricket.io/time-cards-privacy-policy/e5f15605-bef4-4c34-b2f1-149a397dc765/privacy") else { return }
        let browser = SFSafariViewController(url: url)
        browser.dismissButtonStyle = .close
        present(browser, animated: !store.state.reducedMotion)
    }
    @objc private func hapticsChanged(_ sender: UISwitch) {
        store.state.haptics = sender.isOn
        store.save()
        if sender.isOn { feedback() }
    }
    @objc private func motionChanged(_ sender: UISwitch) {
        store.state.reducedMotion = sender.isOn
        store.save()
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
        let name = gameLabel(kind.name + (owned ? "" : " · Locked"), size: 24, color: kind.tint, alignment: .center)
        name.frame = CGRect(x: 16, y: cardH + 44, width: w - 32, height: 34); panel.addSubview(name)
        let description = gameLabel(kind.detail + (owned ? "" : "\nChoose this card after a first clear of Normal level 2, 4 or 6."), size: 14, color: UIColor(hex: 0xDCE6FF), weight: .medium)
        description.numberOfLines = 0
        description.frame = CGRect(x: 25, y: cardH + 84, width: w - 50, height: h - cardH - 167); panel.addSubview(description)
        let close = GameButton("Got It", primary: true); close.titleLabel?.font = Palette.font(20, .heavy)
        close.frame = CGRect(x: 24, y: h - 67, width: w - 48, height: 47)
        close.onTap = { [weak self] in self?.dismiss(animated: true) }; panel.addSubview(close)
    }
}

private extension ViewController {
    func buildContracts() -> CGFloat {
        if let run = store.state.contract {
            if run.battle.outcome != .playing { return buildContractResult() }
            title("Contract Live", frame: CGRect(x: 16, y: 10, width: inner, height: 60), size: 38)
            label("Your next move decides the payout", CGRect(x: 16, y: 77, width: inner, height: 24), size: 14, color: Palette.quiet, align: .center)
            _ = art(9 + run.round, CGRect(x: (width - 156) / 2, y: 127, width: 156, height: 156), radius: 26)
            label("\(run.risk.name) · Round \(run.round + 1) of 3", CGRect(x: 16, y: 308, width: inner, height: 30), size: 23, color: Palette.yellow, align: .center)
            let copy = label("\(run.stake) gold committed · Win this round: \(run.payout)\n\(run.battle.playerHealth) HP · Turn \(run.battle.turn)\nYour adventure is saved separately.", CGRect(x: 24, y: 355, width: width - 48, height: 85), size: 14, color: Palette.quiet, align: .center)
            copy.numberOfLines = 3
            button("Resume Contract", CGRect(x: 18, y: 460, width: inner - 4, height: 55), primary: true) { [weak self] in self?.show(.battle) }.accessibilityIdentifier = "contract.resume"
            button("Contract Rules", CGRect(x: 18, y: 532, width: inner - 4, height: 44)) { [weak self] in self?.showContractRules() }
            button("Abandon · Lose \(run.stake) gold", CGRect(x: 18, y: 594, width: inner - 4, height: 44)) { [weak self] in self?.confirmAbandonContract() }
            return 658
        }
        let small = scroll.bounds.height < 650
        func row(_ y: CGFloat) -> CGFloat {
            guard small else { return y }
            return [7: 2, 63: 51, 89: 78, 182: 151, 212: 179, 270: 235,
                    300: 264, 436: 371, 472: 404, 502: 431, 523: 451,
                    564: 484, 619: 527, 690: 588][y] ?? y
        }
        title("Fate Contracts", frame: CGRect(x: 16, y: row(7), width: inner, height: small ? 44 : 53), size: 36)
        label("PLAY YOUR HAND. KNOW YOUR LIMIT.", CGRect(x: 16, y: row(63), width: inner, height: 20), size: 11, color: Palette.cyan, align: .center)
        let wallet = GamePanel(color: UIColor(hex: 0x49347B))
        wallet.frame = CGRect(x: 16, y: row(89), width: inner, height: small ? 63 : 81); content.addSubview(wallet)
        label("GOLD BALANCE", CGRect(x: 16, y: 11, width: inner - 102, height: 18), size: 10, color: Palette.quiet, parent: wallet)
        label("🪙 \(store.state.chips)", CGRect(x: 16, y: small ? 27 : 32, width: inner - 102, height: small ? 29 : 34), size: 28, color: Palette.yellow, parent: wallet, weight: .heavy)
        button("Rules", CGRect(x: inner - 87, y: small ? 10 : 20, width: 72, height: 40), parent: wallet) { [weak self] in self?.showContractRules() }.accessibilityIdentifier = "contract.rules"
        label("01  CHOOSE YOUR STAKE", CGRect(x: 18, y: row(182), width: inner, height: 22), size: 13, color: Palette.cyan)
        let cell = (inner - 20) / 3
        for (i, stake) in [25, 50, 100].enumerated() {
            let b = button("🪙 \(stake)", CGRect(x: 16 + CGFloat(i) * (cell + 10), y: row(212), width: cell, height: 44), primary: stake == contractStake) { [weak self] in self?.contractStake = stake; self?.feedback(); self?.redraw(preserveScroll: true) }
            b.isEnabled = store.state.chips >= stake
            b.accessibilityIdentifier = "contract.stake.\(stake)"
            b.accessibilityTraits = stake == contractStake ? [.button, .selected] : .button
        }
        label("02  PICK A RISK CONTRACT", CGRect(x: 18, y: row(270), width: inner, height: 22), size: 13, color: Palette.cyan)
        for (i, risk) in ContractRisk.allCases.enumerated() {
            let x = 16 + CGFloat(i) * (cell + 10)
            let panel = GamePanel(color: risk == contractRisk ? UIColor(hex: 0x554083) : Palette.panel)
            panel.frame = CGRect(x: x, y: row(300), width: cell, height: small ? 100 : 127); content.addSubview(panel)
            label(["♧", "♢", "♠"][i], CGRect(x: 4, y: 4, width: cell - 8, height: small ? 27 : 38), size: 32, color: risk == contractRisk ? Palette.yellow : Palette.quiet, align: .center, parent: panel)
            label(risk.name, CGRect(x: 4, y: small ? 33 : 47, width: cell - 8, height: 23), size: 14, align: .center, parent: panel)
            label("Up to \(risk.payoutSteps[2] / 10)×", CGRect(x: 4, y: small ? 58 : 74, width: cell - 8, height: 23), size: 18, color: Palette.yellow, align: .center, parent: panel)
            label(risk == contractRisk ? "SELECTED" : "TAP TO SELECT", CGRect(x: 4, y: small ? 83 : 104, width: cell - 8, height: 14), size: 8, color: Palette.cyan, align: .center, parent: panel)
            let tap = UIButton(frame: panel.bounds)
            tap.tag = i; tap.addTarget(self, action: #selector(contractRiskTapped(_:)), for: .touchUpInside)
            tap.accessibilityLabel = "\(risk.name), \(risk.detail), maximum \(risk.payoutSteps[2] / 10) times stake"
            tap.accessibilityIdentifier = "contract.risk.\(risk.rawValue)"
            tap.accessibilityTraits = risk == contractRisk ? [.button, .selected] : .button
            panel.addSubview(tap)
        }
        label(contractRisk.detail, CGRect(x: 16, y: row(436), width: inner, height: 24), size: 13, color: Palette.quiet, align: .center)
        label("03  WIN. BANK. OR PRESS ON.", CGRect(x: 18, y: row(472), width: inner, height: 22), size: 13, color: Palette.cyan)
        for i in 0..<3 {
            let x = 16 + CGFloat(i) * (cell + 10)
            label("ROUND \(i + 1)", CGRect(x: x, y: row(502), width: cell, height: 19), size: 10, color: Palette.quiet, align: .center)
            label("🪙 \(contractStake * contractRisk.payoutSteps[i] / 10)", CGRect(x: x, y: row(523), width: cell, height: 31), size: 23, color: Palette.yellow, align: .center)
        }
        let note = label("Payout includes your stake. A defeat loses it all.\nHP carries over; your 6-card deck stays locked for the run.", CGRect(x: 18, y: row(564), width: inner - 4, height: small ? 31 : 43), size: 11, color: Palette.quiet, align: .center)
        note.numberOfLines = 2
        let start = button("Commit \(contractStake) · Start Contract", CGRect(x: 18, y: row(619), width: inner - 4, height: small ? 44 : 54), primary: true) { [weak self] in
            guard let self = self, self.store.state.startContract(stake: self.contractStake, risk: self.contractRisk) else { return }
            self.store.save(); self.show(.battle)
        }
        start.isEnabled = store.state.chips >= contractStake
        start.accessibilityIdentifier = "contract.start"
        var y: CGFloat = row(690)
        if store.state.chips < 25 {
            button("Free Gold Refill · +100", CGRect(x: 18, y: y, width: inner - 4, height: 44)) { [weak self] in
                guard let self = self, self.store.state.refillPracticeChips() else { return }
                self.contractStake = 25; self.store.save(); self.redraw()
            }.accessibilityIdentifier = "contract.refill"
            y += 62
        }
        label("Earned in play · No purchases or cash value", CGRect(x: 16, y: y, width: inner, height: 23), size: 11, color: Palette.quiet, align: .center)
        y += 43
        if let wallet = store.state.contractWallet, !wallet.history.isEmpty {
            label("RECENT CONTRACTS · BEST \(wallet.bestRun)/3", CGRect(x: 18, y: y, width: inner, height: 22), size: 12, color: Palette.cyan); y += 34
            for receipt in wallet.history.prefix(5) {
                label("\(receipt.risk.name) · \(receipt.cleared)/3 cleared", CGRect(x: 18, y: y, width: inner - 82, height: 28), size: 13)
                label("\(receipt.net >= 0 ? "+" : "")\(receipt.net)", CGRect(x: width - 93, y: y, width: 75, height: 28), size: 18, color: receipt.net >= 0 ? Palette.green : UIColor(hex: 0xFF8BB2), align: .right)
                y += 37
            }
        }
        return y + 20
    }

    @objc func contractRiskTapped(_ sender: UIButton) {
        contractRisk = ContractRisk.allCases[sender.tag]; feedback(); redraw(preserveScroll: true)
    }

    func buildContractResult() -> CGFloat {
        guard let run = store.state.contract else { return buildContracts() }
        let won = run.battle.outcome == .won
        title(won ? "Bank or Battle?" : "Contract Broken", frame: CGRect(x: 16, y: 12, width: inner, height: 62), color: won ? Palette.yellow : UIColor(hex: 0xFF8BB2), size: 35)
        label(won ? (run.canContinue ? "A sure reward. A harder choice." : "Three victories. Contract complete!") : "The timeline keeps your stake.", CGRect(x: 16, y: 82, width: inner, height: 24), size: 14, color: Palette.quiet, align: .center)
        _ = art(9 + run.round, CGRect(x: (width - 125) / 2, y: 127, width: 125, height: 125), radius: 26)
        label(won ? "🪙 \(run.payout)" : "🪙 −\(run.stake)", CGRect(x: 16, y: 268, width: inner, height: 61), size: 49, color: won ? Palette.yellow : UIColor(hex: 0xFF8BB2), align: .center, weight: .heavy)
        label(won ? "\(String(format: "%.1f", run.multiplier))× stake · Net +\(run.payout - run.stake)" : "Payout 0 · Virtual gold", CGRect(x: 16, y: 334, width: inner, height: 23), size: 14, color: Palette.quiet, align: .center)
        label("\(run.risk.name) · Round \(run.round + 1)/3 · \(run.battle.playerHealth) HP", CGRect(x: 16, y: 369, width: inner, height: 26), size: 16, align: .center)
        button(won ? "Bank \(run.payout) · End Contract" : "Close Contract", CGRect(x: 18, y: 419, width: inner - 4, height: 55), primary: true) { [weak self] in
            guard let self = self, self.store.state.finishContract(bank: won) else { return }
            self.contractStake = self.store.state.chips >= self.contractStake ? self.contractStake : 25
            self.store.save(); self.show(.contracts)
        }.accessibilityIdentifier = "contract.bank"
        if won && run.canContinue {
            let warning = label("Risk all \(run.payout) for \(run.nextPayout) gold\nNext: \(Stage.all[run.round + 1].name) · Enemy attack +\(run.risk.attackBonus)", CGRect(x: 18, y: 492, width: inner - 4, height: 49), size: 13, color: Palette.yellow, align: .center)
            warning.numberOfLines = 2
            button("Mend +6 HP · Continue", CGRect(x: 18, y: 559, width: inner - 4, height: 46)) { [weak self] in self?.pressContract(.mend) }.accessibilityIdentifier = "contract.mend"
            button("Ward +8 Shield · Continue", CGRect(x: 18, y: 622, width: inner - 4, height: 46)) { [weak self] in self?.pressContract(.ward) }.accessibilityIdentifier = "contract.ward"
            let note = label("Choose one boon. HP carries over (maximum 20).\nCards and energy reset; unused shield is cleared.", CGRect(x: 18, y: 684, width: inner - 4, height: 43), size: 11, color: Palette.quiet, align: .center)
            note.numberOfLines = 2
            return 748
        }
        label("Your adventure progress is safe.", CGRect(x: 18, y: 498, width: inner - 4, height: 26), size: 13, color: Palette.quiet, align: .center)
        return 551
    }

    func pressContract(_ boon: ContractBoon) {
        guard store.state.continueContract(boon: boon) else { return }
        store.save(); show(.battle)
    }

    func confirmAbandonContract() {
        guard let run = store.state.contract else { return }
        let alert = UIAlertController(title: "Abandon Contract?", message: "Your committed \(run.stake) gold will be lost. You can resume later instead.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Keep Contract", style: .cancel))
        alert.addAction(UIAlertAction(title: "Abandon", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.store.state.finishContract(bank: false); self.store.save(); self.show(.contracts)
        })
        present(alert, animated: true)
    }

    func showContractRules() {
        let text = "Commit 25, 50 or 100 gold coins to a three-battle run. Choose a risk level: higher risk adds enemy damage and raises payouts. Ruthless starts at 16 HP.\n\nWin a round to bank its total payout, including your stake, or risk it all on the next round. A defeat or abandonment pays zero. The third win must be banked. Payouts are rounded down to whole gold coins.\n\nHealth carries over. Before continuing, choose +6 HP (up to 20) or 8 starting shield. Cards and energy reset. Your deck is locked for the run.\n\nOverdrive trades 3 HP for 2 energy once per turn, up to 5 energy. It cannot be used at 3 HP or less. Enemy attacks are visible; combat has no hidden dice rolls.\n\nCampaign progress is separate. Gold cannot be bought or redeemed. If your balance falls below 25, claim a free 100-gold refill after ending the contract."
        let alert = UIAlertController(title: "Fate Contracts", message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Got It", style: .default)); present(alert, animated: true)
    }
}
