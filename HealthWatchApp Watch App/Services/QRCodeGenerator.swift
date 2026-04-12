import Foundation

/// Pure Swift QR Code generator for watchOS (CoreImage is not available on watchOS).
/// Supports QR versions 1–4, error correction level L, byte mode encoding.
enum QRCodeGenerator {

    // MARK: - Public API

    /// Generates a QR code as a 2D boolean matrix. `true` = dark module.
    /// Returns `nil` if the data is too long or not valid UTF-8.
    static func generate(from string: String) -> [[Bool]]? {
        guard let data = string.data(using: .utf8) else { return nil }
        let bytes = [UInt8](data)

        guard let info = versions.first(where: { maxBytes(for: $0) >= bytes.count }) else {
            return nil
        }

        let dataCW = encodeData(bytes, info)
        let ecCW = rsEncode(data: dataCW, ecCount: info.ecCW)
        let size = info.size
        var matrix = Array(repeating: Array(repeating: false, count: size), count: size)
        var fnMask = Array(repeating: Array(repeating: false, count: size), count: size)

        placeFunctionPatterns(&matrix, &fnMask, info)
        placeDataBits(&matrix, fnMask, dataCW + ecCW, size)
        let mask = selectBestMask(&matrix, fnMask, size)
        placeFormatInfo(&matrix, mask: mask, size: size)
        return matrix
    }

    // MARK: - Version Definitions

    private struct V {
        let version: Int
        let size: Int
        let dataCW: Int
        let ecCW: Int
        let align: [Int]
    }

    private static let versions: [V] = [
        V(version: 1, size: 21, dataCW: 19, ecCW: 7,  align: []),
        V(version: 2, size: 25, dataCW: 34, ecCW: 10, align: [6, 18]),
        V(version: 3, size: 29, dataCW: 55, ecCW: 15, align: [6, 22]),
        V(version: 4, size: 33, dataCW: 80, ecCW: 20, align: [6, 26]),
    ]

    private static func maxBytes(for v: V) -> Int {
        (v.dataCW * 8 - 12) / 8   // 4-bit mode + 8-bit count overhead
    }

    // MARK: - Data Encoding (Byte Mode)

    private static func encodeData(_ bytes: [UInt8], _ info: V) -> [UInt8] {
        var bits: [Bool] = []
        let cap = info.dataCW * 8

        addBits(&bits, 0b0100, 4)            // mode: byte
        addBits(&bits, bytes.count, 8)       // character count
        for b in bytes { addBits(&bits, Int(b), 8) }

        // terminator + byte-align + pad
        addBits(&bits, 0, min(4, cap - bits.count))
        if bits.count % 8 != 0 { addBits(&bits, 0, 8 - bits.count % 8) }
        var pad = 0
        while bits.count < cap {
            addBits(&bits, pad % 2 == 0 ? 0xEC : 0x11, 8)
            pad += 1
        }

        return stride(from: 0, to: cap, by: 8).map { i in
            var byte: UInt8 = 0
            for j in 0..<8 where bits[i + j] { byte |= 1 << UInt8(7 - j) }
            return byte
        }
    }

    private static func addBits(_ bits: inout [Bool], _ val: Int, _ count: Int) {
        for i in stride(from: count - 1, through: 0, by: -1) {
            bits.append((val >> i) & 1 == 1)
        }
    }

    // MARK: - Reed-Solomon (GF(256), primitive poly 0x11D)

    private static let gfExp: [Int] = {
        var e = [Int](repeating: 0, count: 512)
        var v = 1
        for i in 0..<256 { e[i] = v; v <<= 1; if v >= 256 { v ^= 0x11D } }
        for i in 256..<512 { e[i] = e[i - 256] }
        return e
    }()

    private static let gfLog: [Int] = {
        var l = [Int](repeating: 0, count: 256)
        for i in 0..<255 { l[gfExp[i]] = i }
        return l
    }()

    private static func gfMul(_ a: Int, _ b: Int) -> Int {
        guard a != 0 && b != 0 else { return 0 }
        return gfExp[gfLog[a] + gfLog[b]]
    }

    private static func rsEncode(data: [UInt8], ecCount: Int) -> [UInt8] {
        // Build generator polynomial
        var gen = [1]
        for i in 0..<ecCount {
            var next = [Int](repeating: 0, count: gen.count + 1)
            for j in 0..<gen.count {
                next[j] ^= gen[j]
                next[j + 1] ^= gfMul(gen[j], gfExp[i])
            }
            gen = next
        }

        // Polynomial division
        var rem = [Int](repeating: 0, count: ecCount)
        for byte in data {
            let factor = Int(byte) ^ rem[0]
            rem.removeFirst()
            rem.append(0)
            for j in 0..<rem.count {
                rem[j] ^= gfMul(factor, gen[j + 1])
            }
        }
        return rem.map { UInt8($0) }
    }

    // MARK: - Function Patterns

    private static func placeFunctionPatterns(
        _ m: inout [[Bool]], _ f: inout [[Bool]], _ info: V
    ) {
        let s = info.size

        // Three finder patterns with separators
        for (fr, fc) in [(0, 0), (0, s - 7), (s - 7, 0)] {
            placeFinder(&m, &f, fr, fc, s)
        }

        // Timing patterns
        for i in 8..<(s - 8) {
            let dark = i % 2 == 0
            setMod(&m, &f, 6, i, dark, s)
            setMod(&m, &f, i, 6, dark, s)
        }

        // Alignment patterns (version 2+)
        if info.align.count >= 2 {
            for r in info.align {
                for c in info.align {
                    if (r <= 8 && c <= 8) || (r <= 8 && c >= s - 8) || (r >= s - 8 && c <= 8) {
                        continue
                    }
                    placeAlignment(&m, &f, r, c, s)
                }
            }
        }

        // Reserve format info areas
        for i in 0...8 { f[8][i] = true; f[i][8] = true }
        for i in 0...7 { f[8][s - 1 - i] = true; f[s - 1 - i][8] = true }

        // Dark module
        m[s - 8][8] = true
        f[s - 8][8] = true
    }

    private static func placeFinder(
        _ m: inout [[Bool]], _ f: inout [[Bool]], _ row: Int, _ col: Int, _ s: Int
    ) {
        for r in -1...7 {
            for c in -1...7 {
                let rr = row + r, cc = col + c
                guard rr >= 0 && rr < s && cc >= 0 && cc < s else { continue }
                let dark: Bool
                if r < 0 || r > 6 || c < 0 || c > 6 {
                    dark = false
                } else if r == 0 || r == 6 || c == 0 || c == 6 {
                    dark = true
                } else if r >= 2 && r <= 4 && c >= 2 && c <= 4 {
                    dark = true
                } else {
                    dark = false
                }
                m[rr][cc] = dark; f[rr][cc] = true
            }
        }
    }

    private static func placeAlignment(
        _ m: inout [[Bool]], _ f: inout [[Bool]], _ cr: Int, _ cc: Int, _ s: Int
    ) {
        for r in -2...2 {
            for c in -2...2 {
                setMod(&m, &f, cr + r, cc + c,
                       abs(r) == 2 || abs(c) == 2 || (r == 0 && c == 0), s)
            }
        }
    }

    private static func setMod(
        _ m: inout [[Bool]], _ f: inout [[Bool]], _ r: Int, _ c: Int, _ dark: Bool, _ s: Int
    ) {
        guard r >= 0 && r < s && c >= 0 && c < s else { return }
        m[r][c] = dark; f[r][c] = true
    }

    // MARK: - Data Placement

    private static func placeDataBits(
        _ m: inout [[Bool]], _ f: [[Bool]], _ codewords: [UInt8], _ size: Int
    ) {
        var bi = 0
        let total = codewords.count * 8
        var right = size - 1
        var up = true

        while right >= 1 {
            if right == 6 { right = 5 }
            for i in 0..<size {
                let row = up ? (size - 1 - i) : i
                for dx in 0...1 {
                    let col = right - dx
                    guard col >= 0 && !f[row][col] && bi < total else { continue }
                    m[row][col] = (Int(codewords[bi / 8]) >> (7 - bi % 8)) & 1 == 1
                    bi += 1
                }
            }
            up.toggle()
            right -= 2
        }
    }

    // MARK: - Masking

    private static func selectBestMask(
        _ m: inout [[Bool]], _ f: [[Bool]], _ size: Int
    ) -> Int {
        let original = m
        var bestMask = 0, bestPenalty = Int.max

        for mask in 0..<8 {
            m = original
            applyMask(&m, f, mask, size)
            let p = penalty(m, size)
            if p < bestPenalty { bestPenalty = p; bestMask = mask }
        }

        m = original
        applyMask(&m, f, bestMask, size)
        return bestMask
    }

    private static func applyMask(
        _ m: inout [[Bool]], _ f: [[Bool]], _ mask: Int, _ size: Int
    ) {
        for r in 0..<size {
            for c in 0..<size {
                guard !f[r][c] else { continue }
                let flip: Bool
                switch mask {
                case 0: flip = (r + c) % 2 == 0
                case 1: flip = r % 2 == 0
                case 2: flip = c % 3 == 0
                case 3: flip = (r + c) % 3 == 0
                case 4: flip = (r / 2 + c / 3) % 2 == 0
                case 5: flip = (r * c) % 2 + (r * c) % 3 == 0
                case 6: flip = ((r * c) % 2 + (r * c) % 3) % 2 == 0
                default: flip = ((r + c) % 2 + (r * c) % 3) % 2 == 0
                }
                if flip { m[r][c].toggle() }
            }
        }
    }

    private static func penalty(_ m: [[Bool]], _ s: Int) -> Int {
        var p = 0

        // Rule 1: runs of same color in rows/columns
        for r in 0..<s {
            var run = 1
            for c in 1..<s {
                if m[r][c] == m[r][c - 1] { run += 1 }
                else { if run >= 5 { p += run - 2 }; run = 1 }
            }
            if run >= 5 { p += run - 2 }
        }
        for c in 0..<s {
            var run = 1
            for r in 1..<s {
                if m[r][c] == m[r - 1][c] { run += 1 }
                else { if run >= 5 { p += run - 2 }; run = 1 }
            }
            if run >= 5 { p += run - 2 }
        }

        // Rule 2: 2×2 blocks of same color
        for r in 0..<(s - 1) {
            for c in 0..<(s - 1) {
                let v = m[r][c]
                if v == m[r][c+1] && v == m[r+1][c] && v == m[r+1][c+1] { p += 3 }
            }
        }

        // Rule 3: finder-like patterns
        let p1: [Bool] = [true,false,true,true,true,false,true,false,false,false,false]
        let p2: [Bool] = [false,false,false,false,true,false,true,true,true,false,true]
        for r in 0..<s {
            for c in 0...(s - 11) {
                let row = (c..<(c+11)).map { m[r][$0] }
                if row == p1 || row == p2 { p += 40 }
            }
        }
        for c in 0..<s {
            for r in 0...(s - 11) {
                let col = (r..<(r+11)).map { m[$0][c] }
                if col == p1 || col == p2 { p += 40 }
            }
        }

        // Rule 4: dark module ratio
        let dark = m.flatMap { $0 }.filter { $0 }.count
        let pct = dark * 100 / (s * s)
        let lo = abs(pct / 5 * 5 - 50) / 5
        let hi = abs((pct / 5 + 1) * 5 - 50) / 5
        p += min(lo, hi) * 10

        return p
    }

    // MARK: - Format Information (EC Level L, BCH(15,5))

    private static func placeFormatInfo(_ m: inout [[Bool]], mask: Int, size: Int) {
        let bits = formatBits(mask: mask)

        // Copy 1: around top-left finder
        let c1: [(Int, Int)] = [
            (8,0),(8,1),(8,2),(8,3),(8,4),(8,5),(8,7),(8,8),
            (7,8),(5,8),(4,8),(3,8),(2,8),(1,8),(0,8)
        ]
        // Copy 2: around top-right and bottom-left finders
        let c2: [(Int, Int)] = [
            (size-1,8),(size-2,8),(size-3,8),(size-4,8),
            (size-5,8),(size-6,8),(size-7,8),
            (8,size-8),(8,size-7),(8,size-6),(8,size-5),
            (8,size-4),(8,size-3),(8,size-2),(8,size-1)
        ]

        for i in 0..<15 {
            let dark = (bits >> i) & 1 == 1
            m[c1[i].0][c1[i].1] = dark
            m[c2[i].0][c2[i].1] = dark
        }
    }

    private static func formatBits(mask: Int) -> Int {
        let data = (0b01 << 3) | mask   // EC level L = 01
        var rem = data << 10
        for i in stride(from: 4, through: 0, by: -1) {
            if rem & (1 << (i + 10)) != 0 { rem ^= 0b10100110111 << i }
        }
        return ((data << 10) | rem) ^ 0b101010000010010
    }
}
