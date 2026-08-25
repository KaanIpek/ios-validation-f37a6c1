import Social
import UIKit
import UniformTypeIdentifiers

private final class ShareAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var titleValue = ""
    private var textValue = ""
    private var urlValue = ""

    func setTitle(_ value: String) { lock.withLock { titleValue = value } }
    func setText(_ value: String) { lock.withLock { textValue = value } }
    func setURL(_ value: String) { lock.withLock { urlValue = value } }
    func payload() -> SharedRecipePayload {
        lock.withLock {
            SharedRecipePayload(title: titleValue, text: textValue, url: urlValue)
        }
    }
}

final class ShareViewController: UIViewController {
    private let statusLabel = UILabel()
    private let activity = UIActivityIndicatorView(style: .medium)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        statusLabel.text = "Saving to Grocery OS…"
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        activity.startAnimating()
        let stack = UIStackView(arrangedSubviews: [activity, statusLabel])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
        ])
        receiveShare()
    }

    private func receiveShare() {
        let accumulator = ShareAccumulator()
        let group = DispatchGroup()

        for item in extensionContext?.inputItems.compactMap({ $0 as? NSExtensionItem }) ?? [] {
            if let attributedTitle = item.attributedTitle?.string {
                accumulator.setTitle(attributedTitle)
            }
            if let attributedText = item.attributedContentText?.string {
                accumulator.setText(attributedText)
            }
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier) { value, _ in
                        if let url = value as? URL { accumulator.setURL(url.absoluteString) }
                        else if let text = value as? String { accumulator.setURL(text) }
                        group.leave()
                    }
                }
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { value, _ in
                        if let text = value as? String { accumulator.setText(text) }
                        else if let text = value as? NSAttributedString { accumulator.setText(text.string) }
                        group.leave()
                    }
                }
            }
        }

        group.notify(queue: .main) { [weak self] in self?.finish(with: accumulator.payload()) }
    }

    private func finish(with payload: SharedRecipePayload) {
        guard let appGroup = Bundle.main.object(
            forInfoDictionaryKey: "GroceryAppGroupIdentifier"
        ) as? String else {
            fail("This build is missing its secure sharing configuration.")
            return
        }
        do {
            try SharedRecipeStore(appGroupIdentifier: appGroup).save(payload)
            activity.stopAnimating()
            statusLabel.text = "Saved. Open Grocery OS to review the recipe before adding ingredients."
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil)
            }
        } catch {
            fail("Nothing was imported. Copy the public link and paste it in Grocery OS instead.")
        }
    }

    private func fail(_ message: String) {
        activity.stopAnimating()
        statusLabel.text = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.extensionContext?.cancelRequest(
                withError: NSError(domain: "GroceryOSShare", code: 1)
            )
        }
    }
}
