import UIKit
import HintKit

final class DemoViewController: UIViewController {
    private let presenter = HintPresenter(store: HintStore(namespace: "demo"))
    private let photo = UIButton(type: .system)
    private let palette = UIButton(type: .system)
    private let save = UIButton(type: .system)
    private let status = UILabel()

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
        let stack = UIStackView(arrangedSubviews: [title, subtitle, photo, palette, save, help, reset, status])
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
        let options = HintOptions(displayPolicy: force ? .always : .untilCompleted)
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

    @objc private func showHelpAgain() { showHints(force: true) }
    @objc private func resetHistory() {
        presenter.store.resetAll()
        showHints(force: false)
    }
}
