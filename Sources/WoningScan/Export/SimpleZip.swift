import Foundation

/// Minimalistische ZIP-schrijver (alleen "stored", dus zonder compressie) zodat een export van
/// meerdere bestanden (JSON + CSV's + foto's) als één .zip gedeeld kan worden via het iOS-deelvenster,
/// zonder een externe library nodig te hebben.
enum SimpleZip {
    struct Entry {
        let naam: String
        let data: Data
    }

    static func schrijf(_ entries: [Entry], naar url: URL) throws {
        var fileBody = Data()
        var centralDirectory = Data()
        var offset: UInt32 = 0

        for entry in entries {
            let naamData = Array(entry.naam.utf8)
            let crc = crc32(entry.data)
            let size = UInt32(entry.data.count)

            var localHeader = Data()
            localHeader.append(le32(0x04034b50))       // local file header signature
            localHeader.append(le16(20))                // version needed
            localHeader.append(le16(0))                 // flags
            localHeader.append(le16(0))                 // compression method = stored
            localHeader.append(le16(0))                 // mod time
            localHeader.append(le16(0))                 // mod date
            localHeader.append(le32(crc))
            localHeader.append(le32(size))               // compressed size
            localHeader.append(le32(size))               // uncompressed size
            localHeader.append(le16(UInt16(naamData.count)))
            localHeader.append(le16(0))                  // extra field length
            localHeader.append(contentsOf: naamData)

            fileBody.append(localHeader)
            fileBody.append(entry.data)

            var centralEntry = Data()
            centralEntry.append(le32(0x02014b50))        // central directory header signature
            centralEntry.append(le16(20))                 // version made by
            centralEntry.append(le16(20))                 // version needed
            centralEntry.append(le16(0))                  // flags
            centralEntry.append(le16(0))                  // compression method
            centralEntry.append(le16(0))                  // mod time
            centralEntry.append(le16(0))                  // mod date
            centralEntry.append(le32(crc))
            centralEntry.append(le32(size))
            centralEntry.append(le32(size))
            centralEntry.append(le16(UInt16(naamData.count)))
            centralEntry.append(le16(0))                   // extra field length
            centralEntry.append(le16(0))                   // comment length
            centralEntry.append(le16(0))                   // disk number start
            centralEntry.append(le16(0))                   // internal attributes
            centralEntry.append(le32(0))                   // external attributes
            centralEntry.append(le32(offset))              // relative offset of local header
            centralEntry.append(contentsOf: naamData)

            centralDirectory.append(centralEntry)
            offset += UInt32(localHeader.count) + size
        }

        var end = Data()
        end.append(le32(0x06054b50))                       // end of central directory signature
        end.append(le16(0))                                  // disk number
        end.append(le16(0))                                  // disk with central directory
        end.append(le16(UInt16(entries.count)))             // entries on this disk
        end.append(le16(UInt16(entries.count)))             // total entries
        end.append(le32(UInt32(centralDirectory.count)))    // size of central directory
        end.append(le32(offset))                             // offset of central directory
        end.append(le16(0))                                  // comment length

        var geheel = Data()
        geheel.append(fileBody)
        geheel.append(centralDirectory)
        geheel.append(end)

        try geheel.write(to: url, options: .atomic)
    }

    private static func le16(_ value: UInt16) -> Data {
        var v = value.littleEndian
        return Data(bytes: &v, count: 2)
    }

    private static func le32(_ value: UInt32) -> Data {
        var v = value.littleEndian
        return Data(bytes: &v, count: 4)
    }

    /// Standaard CRC-32 (IEEE 802.3), tabel-gebaseerd.
    private static let crcTabel: [UInt32] = {
        (0...255).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 {
                c = (c & 1 != 0) ? (0xEDB88320 ^ (c >> 1)) : (c >> 1)
            }
            return c
        }
    }()

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            let index = (crc ^ UInt32(byte)) & 0xFF
            crc = crcTabel[Int(index)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFFFFFF
    }
}
