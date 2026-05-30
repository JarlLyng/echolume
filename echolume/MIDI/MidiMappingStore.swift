//
//  MidiMappingStore.swift
//  echolume
//
//  Persists global MIDI Learn bindings as JSON in UserDefaults. The backing
//  UserDefaults is injectable so unit tests can use a throwaway suite.
//

import Combine
import Foundation

@MainActor
final class MidiMappingStore: ObservableObject {
    @Published private(set) var bindings: [MidiBinding] = []

    private let defaults: UserDefaults
    private static let key = "echolume.midiMappings"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    // MARK: - Queries

    /// CC number bound to a knob target (for the knob badge), if any.
    func cc(for knob: MidiTarget) -> UInt8? {
        bindings.first { $0.kind == .cc && $0.target == knob }?.number
    }

    /// Note number bound to an action target (for the MIDI section), if any.
    func note(for action: MidiTarget) -> UInt8? {
        bindings.first { $0.kind == .note && $0.target == action }?.number
    }

    func target(forCC cc: UInt8) -> MidiTarget? {
        bindings.first { $0.kind == .cc && $0.number == cc }?.target
    }

    func target(forNote note: UInt8) -> MidiTarget? {
        bindings.first { $0.kind == .note && $0.number == note }?.target
    }

    // MARK: - Mutations

    /// Bind a target to a CC/note number. Replaces any existing binding for the
    /// same target and any existing binding on the same (kind, number) — so a
    /// control and a CC each map to exactly one thing.
    func bind(target: MidiTarget, kind: MidiBinding.Kind, number: UInt8) {
        bindings.removeAll { $0.target == target || ($0.kind == kind && $0.number == number) }
        bindings.append(MidiBinding(kind: kind, number: number, target: target))
        save()
    }

    func removeBinding(for target: MidiTarget) {
        bindings.removeAll { $0.target == target }
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = defaults.data(forKey: Self.key) else { return }
        do {
            bindings = try JSONDecoder().decode([MidiBinding].self, from: data)
        } catch {
            Log.error("MidiMappingStore: failed to decode bindings — \(error.localizedDescription)")
            bindings = []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(bindings)
            defaults.set(data, forKey: Self.key)
        } catch {
            Log.error("MidiMappingStore: failed to encode bindings — \(error.localizedDescription)")
        }
    }
}
