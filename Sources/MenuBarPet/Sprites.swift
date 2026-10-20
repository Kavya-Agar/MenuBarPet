import AppKit

/// Pet frames: the dog skins come from vscode-pets, the rest are sliced or drawn (see Resources/sprites/CREDITS.txt).
enum Sprites {
    static let frames: [Skin: [String: [NSImage]]] = {
        var result: [Skin: [String: [NSImage]]] = [:]
        for skin in Skin.allCases { result[skin] = loadAnims("sprites/\(skin.rawValue)") }
        return result
    }()

    private static func loadAnims(_ subdirectory: String) -> [String: [NSImage]] {
        var anims: [String: [NSImage]] = [:]
        for name in ["idle", "walk", "walk_fast", "run", "lie", "inhale"] {
            var list: [NSImage] = []
            var i = 0
            while let url = Bundle.main.url(forResource: "\(name)_\(i)", withExtension: "png", subdirectory: subdirectory),
                  let img = NSImage(contentsOf: url) {
                list.append(img)
                i += 1
            }
            anims[name] = list
        }
        return anims
    }

    private static var headCache: [String: NSPoint] = [:]

    /// Top of the head for a frame, in image coordinates (y up): the middle of the topmost opaque row.
    /// Lets accessories sit on skins whose head moves between frames.
    static func headTop(_ img: NSImage, key: String, fromX: CGFloat = 0) -> NSPoint {
        if let p = headCache[key] { return p }
        var result = NSPoint(x: img.size.width / 2, y: img.size.height)
        if let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let rep = NSBitmapImageRep(cgImage: cg)
            rows: for row in 0..<rep.pixelsHigh {
                let cols = (0..<rep.pixelsWide).filter { CGFloat($0) >= fromX && (rep.colorAt(x: $0, y: row)?.alphaComponent ?? 0) > 0.5 }
                if let lo = cols.first, let hi = cols.last {
                    result = NSPoint(x: CGFloat(lo + hi + 1) / 2, y: CGFloat(rep.pixelsHigh - row))
                    break rows
                }
            }
        }
        headCache[key] = result
        return result
    }

    /// Visitor frames by name (`sprites/visitors/<name>_<i>.png`).
    static let visitors = load("visitors")
    /// Props drawn on the pet: sleep cap, umbrella, scarf, sweat, fan, bolt.
    static let props = load("props")

    private static func load(_ folder: String) -> [String: [NSImage]] {
        var found: [String: [Int: NSImage]] = [:]
        for url in Bundle.main.urls(forResourcesWithExtension: "png", subdirectory: "sprites/\(folder)") ?? [] {
            let base = url.deletingPathExtension().lastPathComponent
            guard let cut = base.lastIndex(of: "_"), let i = Int(base[base.index(after: cut)...]),
                  let img = NSImage(contentsOf: url) else { continue }
            found[String(base[..<cut]), default: [:]][i] = img
        }
        return found.mapValues { $0.sorted { $0.key < $1.key }.map(\.value) }
    }
}
