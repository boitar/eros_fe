import Flutter
import ImageIO
import Photos
import UniformTypeIdentifiers

/// File-resource import preserves the encoded image, including GIF frames and
/// PNG alpha. No read-library access or post-save asset lookup is required.
final class ErosPhotoLibraryPlugin: NSObject, FlutterPlugin {
    private var saving = false

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "cn.honjow.eros/photos",
                                           binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(ErosPhotoLibraryPlugin(), channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "saveImage" else {
            result(FlutterMethodNotImplemented)
            return
        }
        guard !saving else {
            result(FlutterError(code: "busy", message: "An image save is in progress", details: nil))
            return
        }
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String, !path.isEmpty,
              let name = args["name"] as? String else {
            result(FlutterError(code: "invalid_file", message: "Missing image file", details: nil))
            return
        }
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.isReadableFile(atPath: path),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let type = CGImageSourceGetType(source),
              CGImageSourceGetCount(source) > 0,
              CGImageSourceGetStatus(source) == .statusComplete else {
            result(FlutterError(code: "invalid_file", message: "Unreadable or incomplete image", details: nil))
            return
        }
        guard let resourceType = UTType(type as String), resourceType.conforms(to: .image),
              CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 1,
              ] as CFDictionary) != nil else {
            result(FlutterError(code: "unsupported_format", message: "Unsupported image format", details: type))
            return
        }

        saving = true
        let finish: (Any?) -> Void = { value in
            DispatchQueue.main.async {
                self.saving = false
                result(value)
            }
        }
        let save: (PHAuthorizationStatus) -> Void = { status in
            guard status == .authorized || status == .limited else {
                finish(FlutterError(code: "permission_denied",
                                    message: "Adding photos is not authorized",
                                    details: ["status": status.rawValue]))
                return
            }
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.originalFilename = (name as NSString).lastPathComponent
                options.uniformTypeIdentifier = type as String
                options.shouldMoveFile = false
                request.addResource(with: .photo, fileURL: url, options: options)
            }) { success, error in
                if success {
                    finish(true)
                } else {
                    let nativeError = error as NSError?
                    finish(FlutterError(code: "write_failed",
                                        message: nativeError?.localizedDescription ?? "Photos import failed",
                                        details: ["domain": nativeError?.domain ?? "Photos",
                                                  "code": nativeError?.code ?? -1]))
                }
            }
        }
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .addOnly, handler: save)
        } else {
            save(status)
        }
    }
}
