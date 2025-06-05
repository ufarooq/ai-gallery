import Foundation
import UserNotifications // For placeholder sendNotification

// Matches AGWorkInfo in Kotlin
struct AGWorkInfo: Hashable, Codable {
    let modelName: String
    let workId: String // In iOS, this could be the taskIdentifier or a generated UUID string
}

protocol DownloadRepository {
    func downloadModel(model: Model, onStatusUpdated: @escaping (Model, ModelDownloadStatus) -> Void)
    func cancelDownloadModel(model: Model)
    func cancelAll(models: [Model], onComplete: @escaping () -> Void)
    // observerWorkerProgress and getEnqueuedOrRunningWorkInfos are WorkManager specific.
    // Their direct translation is non-trivial. We'll provide stubs or alternative interpretations.
    func observerWorkerProgress(workerId: String, model: Model, onStatusUpdated: @escaping (Model, ModelDownloadStatus) -> Void)
    func getEnqueuedOrRunningWorkInfos() -> [AGWorkInfo]
}

class DefaultDownloadRepository: NSObject, DownloadRepository {

    private var urlSession: URLSession!
    // Using model.id (which is model.name) as the key for active downloads
    private var activeDownloads: [String: (task: URLSessionDownloadTask, model: Model, onStatusUpdated: (Model, ModelDownloadStatus) -> Void)] = [:]
    private let fileManager = FileManager.default

    private static let backgroundSessionIdentifier = "com.example.GalleryApp.BackgroundDownloader"

    override init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: DefaultDownloadRepository.backgroundSessionIdentifier)
        // config.isDiscretionary = false // Set to true if you want the system to optimize for performance, power, etc.
        // config.sessionSendsLaunchEvents = true // Important for background sessions
        self.urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil) // Use nil for OperationQueue to get callbacks on a dedicated serial queue
        print("DefaultDownloadRepository initialized. Active downloads: \(activeDownloads.count)")
        // Potentially re-attach to existing tasks if the app was terminated
        self.urlSession.getAllTasks { tasks in
            print("Found \(tasks.count) existing tasks on session init.")
            // Further logic needed here to re-associate tasks with models and callbacks if app restarts
        }
    }

    // MARK: - DownloadRepository Protocol

    func downloadModel(model: Model, onStatusUpdated: @escaping (Model, ModelDownloadStatus) -> Void) {
        guard let url = URL(string: model.defaultModelPath) else { // Assuming defaultModelPath is a direct URL for now
            print("Invalid URL for model: \(model.name) - \(model.defaultModelPath)")
            onStatusUpdated(model, ModelDownloadStatus(type: .ERROR, error: "Invalid model URL"))
            return
        }

        if activeDownloads[model.id] != nil {
            print("Download already in progress for model: \(model.name)")
            // Optionally, re-attach the onStatusUpdated callback or notify that download is ongoing
            onStatusUpdated(model, model.downloadStatus) // Send current status
            return
        }

        let downloadTask = urlSession.downloadTask(with: url)
        downloadTask.taskDescription = model.id // Use taskDescription to store model ID

        var mutableModel = model
        mutableModel.downloadStatus = ModelDownloadStatus(type: .DOWNLOADING, progress: 0)
        activeDownloads[model.id] = (task: downloadTask, model: mutableModel, onStatusUpdated: onStatusUpdated)

        onStatusUpdated(mutableModel, mutableModel.downloadStatus)
        downloadTask.resume()
        print("Started download for model: \(model.name), task ID: \(downloadTask.taskIdentifier)")
    }

    func cancelDownloadModel(model: Model) {
        guard let downloadDetails = activeDownloads[model.id] else {
            print("No active download found for model: \(model.name) to cancel.")
            return
        }
        print("Cancelling download for model: \(model.name)")
        downloadDetails.task.cancel()
        // activeDownloads.removeValue(forKey: model.id) // Removal is handled in didCompleteWithError or by user action
        // The delegate method didCompleteWithError will be called with URLError.cancelled
    }

    func cancelAll(models: [Model], onComplete: @escaping () -> Void) {
        print("Cancelling all downloads (\(activeDownloads.count) active)...")
        activeDownloads.values.forEach { $0.task.cancel() }
        // Call onComplete once all cancellation callbacks (didCompleteWithError) have processed.
        // This is tricky because cancellation is asynchronous.
        // For simplicity, calling immediately. A more robust solution would use a DispatchGroup.
        onComplete()
    }

    // This is a WorkManager specific concept.
    // In iOS, progress is typically observed via URLSessionDownloadDelegate.
    // This function could be used to re-attach a callback if the view is recreated.
    func observerWorkerProgress(workerId: String, model: Model, onStatusUpdated: @escaping (Model, ModelDownloadStatus) -> Void) {
        print("observerWorkerProgress called for workerId: \(workerId), model: \(model.name). This is a stub on iOS.")
        // If a download is active for this model, update its callback
        if var downloadDetails = activeDownloads[model.id] {
            // Check if workerId (taskIdentifier) matches, though workerId might be an abstract concept here
            if String(downloadDetails.task.taskIdentifier) == workerId || workerId == model.id { // Assuming workerId might be model.id
                downloadDetails.onStatusUpdated = onStatusUpdated
                activeDownloads[model.id] = downloadDetails
                onStatusUpdated(downloadDetails.model, downloadDetails.model.downloadStatus) // Send current status
            }
        } else {
            // If no active download, report as not downloaded or error
            onStatusUpdated(model, ModelDownloadStatus(type: .NOT_DOWNLOADED))
        }
    }

    // This is also WorkManager specific.
    // We can get active URLSessionTasks.
    func getEnqueuedOrRunningWorkInfos() -> [AGWorkInfo] {
        print("getEnqueuedOrRunningWorkInfos called. This is a stub/adaptation on iOS.")
        var infos: [AGWorkInfo] = []
        // This is synchronous, but getAllTasks is async. For a direct call, this is tricky.
        // This is a simplified snapshot based on current activeDownloads dictionary.
        for (modelId, details) in activeDownloads {
            infos.append(AGWorkInfo(modelName: modelId, workId: String(details.task.taskIdentifier)))
        }
        return infos
        // To get actual system tasks:
        // self.urlSession.getAllTasks { tasks in
        //    infos = tasks.compactMap { task in
        //        guard let modelId = task.taskDescription else { return nil }
        //        return AGWorkInfo(modelName: modelId, workId: String(task.taskIdentifier))
        //    }
        //    // Use a completion handler to return these async results
        // }
        // return [] // if called synchronously
    }

    // MARK: - Helper Methods

    private func getAppSupportDirectory() -> URL {
        return fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    }

    private func getModelsDirectory() -> URL {
        let appSupportDir = getAppSupportDirectory()
        let modelsDir = appSupportDir.appendingPathComponent("models") // Or use model.getPath() structure
        if !fileManager.fileExists(atPath: modelsDir.path) {
            try? fileManager.createDirectory(at: modelsDir, withIntermediateDirectories: true, attributes: nil)
        }
        return modelsDir
    }

    private func getDestinationURL(for model: Model, downloadedFileURL: URL) -> URL {
        // Use a path based on model properties, e.g., model.id or a subfolder
        // For simplicity, using model.id and original file extension or a generic name
        let modelFileName = (URL(string: model.defaultModelPath)?.lastPathComponent) ?? "\(model.id).tflite"
        return getModelsDirectory().appendingPathComponent(modelFileName)
    }

    private func sendNotification(title: String, body: String) {
        print("Placeholder for sendNotification: Title: \(title), Body: \(body)")
        // Actual implementation would use UserNotifications framework
        // Example:
        // let content = UNMutableNotificationContent()
        // content.title = title
        // content.body = body
        // content.sound = .default
        // let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil) // nil trigger = immediate
        // UNUserNotificationCenter.current().add(request) { error in
        //     if let error = error { print("Error sending notification: \(error)") }
        // }
    }
}

// MARK: - URLSessionDownloadDelegate
extension DefaultDownloadRepository: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let modelId = downloadTask.taskDescription, var downloadDetails = activeDownloads[modelId] else {
            print("didWriteData: No download details found for task \(downloadTask.taskIdentifier)")
            return
        }

        let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
        downloadDetails.model.downloadStatus = ModelDownloadStatus(type: .DOWNLOADING, progress: progress)
        activeDownloads[modelId] = downloadDetails // Update model with new status

        // print("Download progress for \(modelId): \(progress)")
        DispatchQueue.main.async {
            downloadDetails.onStatusUpdated(downloadDetails.model, downloadDetails.model.downloadStatus)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let modelId = downloadTask.taskDescription, var downloadDetails = activeDownloads[modelId] else {
            print("didFinishDownloadingTo: No download details for task \(downloadTask.taskIdentifier), \(String(describing: downloadTask.taskDescription))")
            // Potentially a task from a previous session, needs more robust handling for re-association
            return
        }

        print("Finished downloading for model \(modelId) to temporary location: \(location.path)")

        let destinationURL = getDestinationURL(for: downloadDetails.model, downloadedFileURL: location)

        do {
            // Remove existing file if any, to prevent move error
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: location, to: destinationURL)
            print("Moved downloaded file to: \(destinationURL.path)")

            // TODO: Add unzipping logic if model.isZip is true
            // For now, assume it's not a zip or unzipping is handled elsewhere

            downloadDetails.model.downloadStatus = ModelDownloadStatus(type: .DOWNLOADED)
            activeDownloads.removeValue(forKey: modelId) // Download complete, remove from active

            DispatchQueue.main.async {
                downloadDetails.onStatusUpdated(downloadDetails.model, downloadDetails.model.downloadStatus)
                self.sendNotification(title: "Download Complete", body: "\(downloadDetails.model.name) has finished downloading.")
            }
        } catch {
            print("Error moving downloaded file for \(modelId): \(error)")
            downloadDetails.model.downloadStatus = ModelDownloadStatus(type: .ERROR, error: error.localizedDescription)
            activeDownloads.removeValue(forKey: modelId)
            DispatchQueue.main.async {
                downloadDetails.onStatusUpdated(downloadDetails.model, downloadDetails.model.downloadStatus)
            }
        }
    }
}

// MARK: - URLSessionDelegate & URLSessionTaskDelegate
extension DefaultDownloadRepository: URLSessionDelegate, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let modelId = task.taskDescription, var downloadDetails = activeDownloads[modelId] else {
            // This can happen if the task was cancelled and already removed,
            // or if it's a task from a previous session not fully re-associated.
            if let error = error {
                 print("didCompleteWithError: No download details for task \(task.taskIdentifier). Error: \(error.localizedDescription)")
            } else {
                 print("didCompleteWithError: No download details for task \(task.taskIdentifier) and no specific error (possibly completed or cancelled without error).")
            }
            return
        }

        activeDownloads.removeValue(forKey: modelId) // Remove from active downloads

        if let error = error {
            if (error as NSError).code == URLError.cancelled.rawValue {
                print("Download cancelled for model \(modelId)")
                downloadDetails.model.downloadStatus = ModelDownloadStatus(type: .NOT_DOWNLOADED) // Or a specific CANCELED status
            } else {
                print("Download failed for model \(modelId): \(error.localizedDescription)")
                downloadDetails.model.downloadStatus = ModelDownloadStatus(type: .ERROR, error: error.localizedDescription)
            }
        } else {
            // If error is nil, it means didFinishDownloadingTo should have been called.
            // However, if it's still in activeDownloads here, something might be off,
            // or it completed but wasn't removed by didFinishDownloadingTo (which it should be).
            // For safety, ensure status is DOWNLOADED if no error.
            if downloadDetails.model.downloadStatus.type != .DOWNLOADED {
                 print("Task \(task.taskIdentifier) for model \(modelId) completed without error, but status wasn't DOWNLOADED. Forcing.")
                // This case should ideally not be hit if didFinishDownloadingTo works correctly.
                downloadDetails.model.downloadStatus = ModelDownloadStatus(type: .DOWNLOADED)
            }
        }

        DispatchQueue.main.async {
            downloadDetails.onStatusUpdated(downloadDetails.model, downloadDetails.model.downloadStatus)
        }
    }

    // Handle session invalidation or background session completion if needed
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            // This is called when all tasks for a background session have completed.
            // If you have a completion handler from the AppDelegate, call it here.
            // e.g., if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
            //    let backgroundCompletionHandler = appDelegate.backgroundSessionCompletionHandler {
            //     backgroundCompletionHandler()
            //     appDelegate.backgroundSessionCompletionHandler = nil
            // }
            print("All tasks for background session \(session.configuration.identifier ?? "unknown") did finish.")
        }
    }
}
