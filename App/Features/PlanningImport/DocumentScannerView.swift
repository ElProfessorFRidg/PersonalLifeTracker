import SwiftUI
import VisionKit

/// Scanner de documents du système (détection des bords, correction de perspective). Section 138.
/// À n'afficher que si `isAvailable` : il n'existe pas dans le simulateur.
struct DocumentScannerView: UIViewControllerRepresentable {
    /// Première page scannée et nombre de pages.
    let onFinish: (UIImage?, Int) -> Void
    let onCancel: () -> Void

    static var isAvailable: Bool {
        return VNDocumentCameraViewController.isSupported
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(onFinish: onFinish, onCancel: onCancel)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let onFinish: (UIImage?, Int) -> Void
        private let onCancel: () -> Void

        init(onFinish: @escaping (UIImage?, Int) -> Void, onCancel: @escaping () -> Void) {
            self.onFinish = onFinish
            self.onCancel = onCancel
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            let count = scan.pageCount
            let image: UIImage? = count > 0 ? scan.imageOfPage(at: 0) : nil
            onFinish(image, count)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            onFinish(nil, 0)
        }
    }
}
