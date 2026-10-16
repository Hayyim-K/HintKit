import UIKit
import HintKit

final class DemoViewController: UIViewController {
    private var presenter = HintPresenter(store: HintStore(namespace: "demo"))
    private let photo = UIButton(type: .system)
    private let palette = UIButton(type: .system)
    private let save = UIButton(type: .system)
    private let status = UILabel()
    private let pointer = UISegmentedControl(items: ["Tail", "Arrows", "Both", "None"])
    private let theme = UISegmentedControl(items: ["System", "Paper", "Night"])
    private let pointerStyles: [HintPointerStyle] = [.tail, .arrows, .tailAndArrows, .none]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        if CommandLine.arguments.contains("-HintKitDemoResetHistory") { presenter.store.resetAll() }
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        let title = UILabel()
        title.text = "HintKit Demo"
        title.font = .preferredFont(forTextStyle: .largeTitle)
        title.adjustsFontForContentSizeCategory = true
        let subtitle = UILabel()
        subtitle.text = "One UIKit implementation for iOS 15 and later."
        subtitle.numberOfLines = 0
        subtitle.font = .preferredFont(forTextStyle: .body)
        subtitle.adjustsFontForContentSizeCategory = true
        var configuration = UIButton.Configuration.tinted()
        configuration.image = UIImage(systemName: "person.crop.rectangle.fill")
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 48)
        configuration.title = "Choose photo"
        configuration.imagePlacement = .top
        configuration.imagePadding = 12
        photo.configuration = configuration
        photo.accessibilityIdentifier = "demo.photo"
        photo.heightAnchor.constraint(equalToConstant: 140).isActive = true
        configure(palette, title: "Palette", image: "paintpalette.fill", action: #selector(paletteTapped))
        configure(save, title: "Save", image: "square.and.arrow.down", action: #selector(saveTapped))
        palette.accessibilityIdentifier = "demo.palette"
        save.accessibilityIdentifier = "demo.save"
        photo.addTarget(self, action: #selector(photoTapped), for: .touchUpInside)
        let help = UIButton(type: .system)
        configure(help, title: "Show help again", image: "questionmark.circle", action: #selector(showHelpAgain))
        help.accessibilityIdentifier = "demo.help"
        let reset = UIButton(type: .system)
        configure(reset, title: "Reset demo history", image: "arrow.counterclockwise", action: #selector(resetHistory))
        status.text = "Tap the highlighted control to complete its hint."
        status.numberOfLines = 0
        status.font = .preferredFont(forTextStyle: .footnote)
        status.adjustsFontForContentSizeCategory = true
        pointer.selectedSegmentIndex = 0
        pointer.accessibilityIdentifier = "demo.pointer"
        pointer.addTarget(self, action: #selector(pointerChanged), for: .valueChanged)
        theme.selectedSegmentIndex = 0
        theme.accessibilityIdentifier = "demo.theme"
        theme.addTarget(self, action: #selector(themeChanged), for: .valueChanged)
        let stack = UIStackView(arrangedSubviews: [title, subtitle, pointer, theme, photo, palette, save, help, reset, status])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -48)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showHints(force: false)
    }

    override func viewWillDisappear(_ animated: Bool) {
        presenter.cancelAll()
        super.viewWillDisappear(animated)
    }

    private func configure(_ button: UIButton, title: String, image: String, action: Selector) {
        var configuration = UIButton.Configuration.tinted()
        configuration.title = title
        configuration.image = UIImage(systemName: image)
        configuration.imagePadding = 12
        button.configuration = configuration
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    private func showHints(force: Bool) {
        presenter.cancelAll()
        let options = HintOptions(displayPolicy: force ? .always : .untilCompleted,
                                  pointerStyle: pointerStyles[pointer.selectedSegmentIndex])
        presenter.enqueue(Hint(id: "demo.photo", title: "Choose a photo",
                               message: "Tap the photo button. The app remains interactive while this card is visible.",
                               imageName: "photo"), near: photo, in: self, options: options)
        presenter.enqueue(Hint(id: "demo.palette", title: "Try the palette",
                               message: "Tap Palette to complete this step. The next hint appears automatically.",
                               imageName: "paintpalette.fill"), near: palette, in: self, options: options)
        presenter.enqueue(Hint(id: "demo.save", title: "Save your result",
                               message: "This demo does not access your photo library. Tap Save to complete the sequence.",
                               imageName: "square.and.arrow.down"), near: save, in: self, options: options)
    }

    @objc private func photoTapped() {
        status.text = "Photo action completed. The palette hint can now appear."
        presenter.markCompleted("demo.photo")
    }

    @objc private func paletteTapped() {
        status.text = "Palette action completed."
        presenter.markCompleted("demo.palette")
    }

    @objc private func saveTapped() {
        status.text = "All demo actions completed. Use Show help again to replay the hints."
        presenter.markCompleted("demo.save")
    }

    @objc private func themeChanged() {
        let style: HintStyle
        switch theme.selectedSegmentIndex {
        case 1:
            style = HintStyle(backgroundColor: UIColor(red: 1, green: 0.96, blue: 0.86, alpha: 1),
                              foregroundColor: .brown, tintColor: .brown,
                              titleFont: UIFont(name: "Georgia-Bold", size: 19),
                              messageFont: UIFont(name: "Georgia", size: 17),
                              border: HintBorder(color: .brown, width: 1.5),
                              shadow: .custom(color: .brown, opacity: 0.2, radius: 10, offset: CGSize(width: 0, height: 4)))
        case 2:
            style = HintStyle(cornerRadius: 24,
                              backgroundColor: UIColor(red: 0.10, green: 0.12, blue: 0.19, alpha: 0.98),
                              foregroundColor: .white, tintColor: .systemTeal,
                              titleFont: .monospacedSystemFont(ofSize: 19, weight: .bold),
                              messageFont: .systemFont(ofSize: 18, weight: .medium),
                              border: HintBorder(color: .systemTeal, width: 1.5),
                              shadow: .custom(opacity: 0.35, radius: 14, offset: CGSize(width: 0, height: 6)))
        default:
            style = HintStyle()
        }
        presenter.cancelAll()
        presenter = HintPresenter(store: presenter.store, style: style)
        showHints(force: true)
    }

    @objc private func pointerChanged() { showHints(force: true) }

    @objc private func showHelpAgain() { showHints(force: true) }
    @objc private func resetHistory() {
        presenter.store.resetAll()
        showHints(force: false)
    }
}
