//
//  ContentType.swift
//  SwiftWebServer
//
//  Content type definitions with MIME type mappings
//

import Foundation

/// Content type enumeration with MIME type mappings
public enum ContentType: String, CaseIterable, CustomStringConvertible {
    
    // MARK: - Text Types
    case textPlain = "text/plain"
    case textHtml = "text/html"
    case textCss = "text/css"
    case textJavascript = "text/javascript"
    case textXml = "text/xml"
    case textCsv = "text/csv"
    case textMarkdown = "text/markdown"
    
    // MARK: - Application Types
    case applicationJson = "application/json"
    case applicationXml = "application/xml"
    case applicationJavascript = "application/javascript"
    case applicationPdf = "application/pdf"
    case applicationZip = "application/zip"
    case applicationGzip = "application/gzip"
    case applicationTar = "application/x-tar"
    case applicationOctetStream = "application/octet-stream"
    case applicationFormUrlencoded = "application/x-www-form-urlencoded"
    case applicationFormData = "multipart/form-data"
    case applicationSql = "application/sql"
    case applicationRtf = "application/rtf"
    case applicationMsword = "application/msword"
    case applicationMsexcel = "application/vnd.ms-excel"
    case applicationMspowerpoint = "application/vnd.ms-powerpoint"
    
    // MARK: - Image Types
    case imageJpeg = "image/jpeg"
    case imagePng = "image/png"
    case imageGif = "image/gif"
    case imageBmp = "image/bmp"
    case imageWebp = "image/webp"
    case imageSvg = "image/svg+xml"
    case imageIco = "image/x-icon"
    case imageTiff = "image/tiff"
    

    
    // MARK: - Properties
    
    /// The MIME type string
    public var mimeType: String {
        return rawValue
    }
    
    /// File extensions commonly associated with this content type
    public var fileExtensions: [String] {
        switch self {
        // Text
        case .textPlain: return ["txt", "text"]
        case .textHtml: return ["html", "htm"]
        case .textCss: return ["css"]
        case .textJavascript: return ["js", "mjs"]
        case .textXml: return ["xml"]
        case .textCsv: return ["csv"]
        case .textMarkdown: return ["md", "markdown"]
            
        // Application
        case .applicationJson: return ["json"]
        case .applicationXml: return ["xml"]
        case .applicationJavascript: return ["js", "mjs"]
        case .applicationPdf: return ["pdf"]
        case .applicationZip: return ["zip"]
        case .applicationGzip: return ["gz", "gzip"]
        case .applicationTar: return ["tar"]
        case .applicationOctetStream: return ["bin", "exe", "dmg"]
        case .applicationFormUrlencoded: return []
        case .applicationFormData: return []
        case .applicationSql: return ["sql"]
        case .applicationRtf: return ["rtf"]
        case .applicationMsword: return ["doc", "docx"]
        case .applicationMsexcel: return ["xls", "xlsx"]
        case .applicationMspowerpoint: return ["ppt", "pptx"]
            
        // Image
        case .imageJpeg: return ["jpg", "jpeg"]
        case .imagePng: return ["png"]
        case .imageGif: return ["gif"]
        case .imageBmp: return ["bmp"]
        case .imageWebp: return ["webp"]
        case .imageSvg: return ["svg"]
        case .imageIco: return ["ico"]
        case .imageTiff: return ["tiff", "tif"]

        }
    }
    
    /// Whether this content type is text-based
    public var isText: Bool {
        return mimeType.hasPrefix("text/") || 
               self == .applicationJson || 
               self == .applicationXml || 
               self == .applicationJavascript ||
               self == .imageSvg
    }
    
    /// Whether this content type is binary
    public var isBinary: Bool {
        return !isText
    }
    
    /// Whether this content type represents an image
    public var isImage: Bool {
        return mimeType.hasPrefix("image/")
    }
    
    /// Default charset for text-based content types
    public var defaultCharset: String? {
        return isText ? "utf-8" : nil
    }
    
    // MARK: - CustomStringConvertible
    public var description: String {
        return mimeType
    }
    
    // MARK: - Content-Type Header Value
    public func headerValue(charset: String? = nil) -> String {
        if let charset = charset ?? defaultCharset {
            return "\(mimeType); charset=\(charset)"
        }
        return mimeType
    }
}

// MARK: - Static Methods
public extension ContentType {
    
    /// Determine content type from file extension
    static func from(fileExtension: String) -> ContentType {
        let ext = fileExtension.lowercased()
        
        for contentType in ContentType.allCases {
            if contentType.fileExtensions.contains(ext) {
                return contentType
            }
        }
        
        return .applicationOctetStream
    }
    
    /// Determine content type from file path
    static func from(filePath: String) -> ContentType {
        let url = URL(fileURLWithPath: filePath)
        let fileExtension = url.pathExtension
        return from(fileExtension: fileExtension)
    }
    
    /// Parse content type from Content-Type header value
    static func parse(headerValue: String) -> (contentType: ContentType, charset: String?) {
        let components = headerValue.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
        
        guard let mimeType = components.first else {
            return (.applicationOctetStream, nil)
        }
        
        let contentType = ContentType(rawValue: String(mimeType)) ?? .applicationOctetStream
        
        // Extract charset if present
        var charset: String? = nil
        for component in components.dropFirst() {
            if component.lowercased().hasPrefix("charset=") {
                charset = String(component.dropFirst(8))
                break
            }
        }
        
        return (contentType, charset)
    }
    
    /// Common web content types
    static let webContentTypes: [ContentType] = [
        .textHtml, .textCss, .textJavascript, .applicationJson,
        .imageJpeg, .imagePng, .imageGif, .imageSvg, .imageIco
    ]
    
    /// Common document content types
    static let documentContentTypes: [ContentType] = [
        .applicationPdf, .applicationMsword, .applicationMsexcel, 
        .applicationMspowerpoint, .textPlain, .textCsv
    ]
    
    /// Common media content types
    static let mediaContentTypes: [ContentType] = [
        .imageJpeg, .imagePng, .imageGif
    ]
}
