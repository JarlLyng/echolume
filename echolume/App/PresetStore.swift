//
//  PresetStore.swift
//  echolume
//
//  Persists named visual presets as JSON in Application Support. This is the
//  app's only file-based store; everything else lives in UserDefaults. The
//  directory is injectable so unit tests can use a throwaway location.
//

import Combine
import Foundation

enum PresetError: LocalizedError, Equatable {
    case emptyName
    case duplicateName(String)

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Preset name can't be empty."
        case .duplicateName(let name):
            return "A preset named \"\(name)\" already exists."
        }
    }
}

@MainActor
final class PresetStore: ObservableObject {
    /// Ordered list. The order is also the slot order for keyboard recall (⌘1…9).
    @Published private(set) var presets: [VisualPreset] = []

    private let fileURL: URL

    /// - Parameter directory: folder that holds `presets.json`. Defaults to
    ///   `Application Support/<bundleID>/`. Tests pass a temp directory.
    init(directory: URL? = nil) {
        let dir = directory ?? Self.defaultDirectory()
        fileURL = dir.appendingPathComponent("presets.json")
        Self.ensureDirectory(dir)
        load()
    }

    // MARK: - Queries

    func contains(name: String) -> Bool {
        let key = normalized(name)
        return presets.contains { $0.name.lowercased() == key }
    }

    /// Case-insensitive lookup by name (used by the `!preset` Twitch command).
    func preset(named name: String) -> VisualPreset? {
        let key = normalized(name)
        return presets.first { $0.name.lowercased() == key }
    }

    /// 1-based slot lookup for keyboard recall (⌘1…9). Returns nil if empty.
    func preset(atSlot slot: Int) -> VisualPreset? {
        let index = slot - 1
        guard presets.indices.contains(index) else { return nil }
        return presets[index]
    }

    // MARK: - Mutations

    /// Adds a preset after trimming and validating its name. The stored preset
    /// (with the trimmed name) is returned so callers can reference it.
    @discardableResult
    func add(_ preset: VisualPreset) throws -> VisualPreset {
        let trimmed = preset.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PresetError.emptyName }
        guard !contains(name: trimmed) else { throw PresetError.duplicateName(trimmed) }
        var stored = preset
        stored.name = trimmed
        presets.append(stored)
        save()
        return stored
    }

    func delete(id: UUID) {
        presets.removeAll { $0.id == id }
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            presets = try JSONDecoder().decode([VisualPreset].self, from: data)
        } catch {
            Log.error("PresetStore: failed to load presets — \(error.localizedDescription)")
            presets = []
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(presets)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            Log.error("PresetStore: failed to save presets — \(error.localizedDescription)")
        }
    }

    private func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func ensureDirectory(_ dir: URL) {
        guard !FileManager.default.fileExists(atPath: dir.path) else { return }
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            Log.error("PresetStore: failed to create directory — \(error.localizedDescription)")
        }
    }

    private static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let bundleID = Bundle.main.bundleIdentifier ?? "com.iamjarl.echolume"
        return base.appendingPathComponent(bundleID, isDirectory: true)
    }
}
