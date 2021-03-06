//
//  GoogleBooksAPI.swift
//  books
//
//  Created by Andrew Bennet on 12/11/2016.
//  Copyright © 2016 Andrew Bennet. All rights reserved.
//

import Foundation
import SwiftyJSON
import RxSwift

class GoogleBooks {
    
    static func searchTextObservable(_ text: String) -> Observable<SearchResultsPage> {
        return Observable<SearchResultsPage>.createFrom { callback -> URLSessionDataTask in
            return GoogleBooks.searchText(text, callback: callback)
        }
    }
    
    /**
     Searches on Google Books for the given search string, and calls the callback when a result is received
    */
    static func searchText(_ text: String, callback: @escaping (SearchResultsPage) -> Void) -> URLSessionDataTask {
        return requestJson(from: Request.searchText(text).url) { result in
            
            // Check for HTTP error
            guard result.isSuccess else {
                callback(SearchResultsPage.error(result.error!, fromSearchText: text))
                return
            }
            
            // Check for errors reported by Google
            let googleError = Parser.parseError(json: result.value!)
            guard googleError == nil else {
                callback(SearchResultsPage.error(googleError!, fromSearchText: text))
                return
            }
            
            let results = Parser.parseSearchResults(result.value!)
            callback(SearchResultsPage(results, fromSearchText: text))
        }
    }
    
    /**
     Searches on Google Books for the given search string, and calls the callback when a result is received.
     */
    static func fetchIsbn(_ isbn: String, callback: @escaping (FetchResultPage) -> Void) {
        #if DEBUG
            print("Fetching ISBN \(isbn)")
        #endif
        let request = Request.searchIsbn(isbn)
        requestJson(from: request.url) { result in
            
            // Check for HTTP errors
            guard result.isSuccess else {
                callback(FetchResultPage.error(result.error!, fromRequest: request))
                return
            }
            
            // Check for errors reported by Google
            let googleError = Parser.parseError(json: result.value!)
            guard googleError == nil else {
                callback(FetchResultPage.error(googleError!, fromRequest: request))
                return
            }
            
            let results = Parser.parseSearchResults(result.value!)
            guard let id = results.first?.id else { callback(FetchResultPage.empty(fromRequest: request)); return }
            GoogleBooks.fetch(googleBooksId: id, callback: callback)
        }
    }
    
    /**
     Fetches the specified book from Google Books.
     */
    static func fetch(googleBooksId: String, callback: @escaping (FetchResultPage) -> Void) {
        #if DEBUG
            print("Fetching GBID \(googleBooksId)")
        #endif
        let request = Request.fetch(googleBooksId)
        requestJson(from: request.url) { result in
            // Check for HTTP errors
            guard result.isSuccess else {
                callback(FetchResultPage.error(result.error!, fromRequest: request))
                return
            }
            
            // Check for errors reported by Google
            let googleError = Parser.parseError(json: result.value!)
            guard googleError == nil else {
                callback(FetchResultPage.error(googleError!, fromRequest: request))
                return
            }
            
            guard let result = Parser.parseFetchResults(result.value!) else {
                callback(FetchResultPage.empty(fromRequest: request))
                return
            }
            
            getCover(googleBooksId: result.id) { coverResult in
                if coverResult.isSuccess {
                    result.coverImage = coverResult.value!
                }
                callback(FetchResultPage(result, fromRequest: request))
            }
        }
    }
    
    /**
     Gets the cover image data for the book corresponding to the Google Books ID (if exists).
    */
    static func getCover(googleBooksId: String, callback: @escaping (Result<Data>) -> Void) {
        // Just use the thumbnail cover images for now
        let coverRequest = Request.coverImage(googleBooksId, .thumbnail)
        requestData(from: coverRequest.url, callback: callback)
    }
    
    static func getCover(isbn: String, callback: @escaping (Result<Data>) -> Void) {
        // If we are going by the ISBN, fetch the result first
        // This could become redundant if we supplement ISBN -> GBID first.
        GoogleBooks.fetchIsbn(isbn) { fetchResult in
            guard fetchResult.result.isSuccess else { callback(Result.failure(fetchResult.result.error!)); return }
            
            getCover(googleBooksId: fetchResult.result.value!.id) { coverResult in
                callback(coverResult)
            }
        }
    }
    
    @discardableResult private static func requestJson(from url: URL, callback: @escaping (Result<JSON>) -> Void) -> URLSessionDataTask {
        #if DEBUG
            print("Requesting \(url.absoluteString)")
        #endif
        let webRequest = URLSession.shared.dataTask(with: url) { (data, _, error) in
            guard error == nil else { callback(Result.failure(error!)); return }
            guard let json = JSON(optionalData: data) else { callback(Result.failure(GoogleErrorType.noJsonData)); return }
            callback(Result<JSON>.success(json))
        }
        webRequest.resume()
        return webRequest
    }
    
    @discardableResult static func requestData(from url: URL, callback: @escaping (Result<Data>) -> Void) -> URLSessionDataTask {
        #if DEBUG
            print("Requesting \(url.absoluteString)")
        #endif
        let webRequest = URLSession.shared.dataTask(with: url) { (data, _, error) in
            guard error == nil else { callback(Result.failure(error!)); return }
            guard let data = data else { callback(Result.failure(GoogleErrorType.noData)); return }
            callback(Result<Data>.success(data))
        }
        webRequest.resume()
        return webRequest
    }
    
    enum Request {
        
        case searchText(String)
        case searchIsbn(String)
        case fetch(String)
        case coverImage(String, CoverType)
        case webpage(String)
        
        enum CoverType : Int {
            case thumbnail = 1
            case small = 2
        }
        
        // The base URL for GoogleBooks API v1 requests
        private static let apiBaseUrl = URL(string: "https://www.googleapis.com")!
        private static let googleBooksBaseUrl = URL(string: "https://books.google.com")!
        
        private static let searchResultFields = "items(id,volumeInfo(title,authors,industryIdentifiers,categories,imageLinks/thumbnail))"
        private static let apiKey = "AIzaSyAN64W_QrynoqZB3Sxdm1PudVOdjvU69Qo"
        // The API Key is limited to 1000 requests per day. Removed the real-time search
        // feature - hopefully searching without an API key is possible now.
        private static let useApiKey = false

        var url: URL {
            switch self{
            case let .searchText(searchString):
                let encodedQuery = searchString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
                let relativeUrl = "/books/v1/volumes?q=\(encodedQuery)&maxResults=40&fields=\(Request.searchResultFields)\(Request.useApiKey ? "&key=\(Request.apiKey)" : "")"
                return URL(string: relativeUrl, relativeTo: Request.apiBaseUrl)!
                
            case let .searchIsbn(isbn):
                let relativeUrl = "/books/v1/volumes?q=isbn:\(isbn)&maxResults=40&fields=\(Request.searchResultFields)\(Request.useApiKey ? "&key=\(Request.apiKey)" : "")"
                return URL(string: relativeUrl, relativeTo: Request.apiBaseUrl)!
                
            case let .fetch(id):
                return URL(string: "/books/v1/volumes/\(id)\(Request.useApiKey ? "?key=\(Request.apiKey)" : "")", relativeTo: Request.apiBaseUrl)!
            
            case let .coverImage(googleBooksId, coverType):
                return URL(string: "/books/content?id=\(googleBooksId)&printsec=frontcover&img=1&zoom=\(coverType.rawValue)", relativeTo: Request.googleBooksBaseUrl)!
                
            case let .webpage(googleBooksId):
                return URL(string: "/books?id=\(googleBooksId)", relativeTo: Request.googleBooksBaseUrl)!
            }
        }
    }
    
    class Parser {
        
        static func parseError(json: JSON) -> GoogleError? {
            if let code = json["error", "code"].int, let message = json["error", "message"].string {
                return GoogleError(code: code, message: message)
            }
            return nil
        }
        
        static func parseSearchResults(_ searchResults: JSON) -> [SearchResult] {
            return searchResults["items"].flatMap { itemJson in
                guard let item = Parser.parseItem(itemJson.1) else { return nil }
                return item
            }
        }
        
        static func parseItem(_ item: JSON) -> SearchResult? {
            guard let id = item["id"].string,
                let title = item["volumeInfo", "title"].string,
                let authors = item["volumeInfo", "authors"].array else { return nil }
                
            let singleAuthorListString = authors.map{$0.rawString()!}.joined(separator: ", ")
            let result = SearchResult(id: id, title: title, authors: singleAuthorListString)
            
            result.thumbnailCoverUrl = URL(optionalString: item["volumeInfo","imageLinks","thumbnail"].string)?.toHttps()
            result.isbn13 = item["volumeInfo","industryIdentifiers"].array?.first(where: { json in
                return json["type"].stringValue == "ISBN_13"
            })?["identifier"].stringValue
            
            return result
        }
        
        static func parseFetchResults(_ fetchResult: JSON) -> FetchResult? {
            
            // Defer to the common search parsing initially
            guard let searchResult = Parser.parseItem(fetchResult) else { return nil }
            
            let result = FetchResult(fromSearchResult: searchResult)
            result.pageCount = fetchResult["volumeInfo","pageCount"].int
            // "Published Date" refers to *this* edition; there doesn't seem to be a way to get the first publication date :(
            //result.publishedDate = fetchResult["volumeInfo","publishedDate"].string?.toDateViaFormat("yyyy-MM-dd")

            result.hasSmallImage = fetchResult["volumeInfo","imageLinks","small"].string != nil
            result.hasThumbnailImage = fetchResult["volumeInfo","imageLinks","thumbnail"].string != nil
            
            // This string may contain some HTML. We want to remove them, but first we might as well replace the "<br>"s with '\n's
            // and the "<p>"s with "\n\n".
            var description = fetchResult["volumeInfo","description"].string
            description = description?.components(separatedBy: "<br>").map{$0.trimming()}.joined(separator: "\n")
            description = description?.components(separatedBy: "<p>").map{$0.trimming()}.joined(separator: "\n\n")
            description = description?.replacingOccurrences(of: "</p>", with: "")
            description = description?.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
            description = description?.trimmingCharacters(in: .whitespacesAndNewlines)
            result.description = description
            
            // Try to get the categories
            if let subjects = fetchResult["volumeInfo", "categories"].array {
                result.subjects = subjects.flatMap{
                    $0.stringValue.components(separatedBy: "/").map{$0.trimming()}
                }.filter{ $0 != "General" }.distinct()
            }
            
            return result
        }
    }
    
    enum GoogleErrorType: Error {
        case noResult
        case noJsonData
        case noData
    }
    
    class GoogleError: Error {
        let code: Int
        let message: String
        
        init(code: Int, message: String) {
            self.code = code
            self.message = message
        }
    }
    
    class SearchResult {
        let id: String
        var title: String
        var authors: String
        var isbn13: String?
        var thumbnailCoverUrl: URL?
        
        init(id: String, title: String, authors: String) {
            self.id = id
            self.title = title
            self.authors = authors
        }
    }
    
    class FetchResult {
        let id: String
        var title: String
        var authors: String
        var isbn13: String?
        var description: String?
        var subjects = [String]()
        var publishedDate: Date?
        var pageCount: Int?
        var hasThumbnailImage: Bool = false
        var hasSmallImage: Bool = false
        
        var coverImage: Data?
        
        init(fromSearchResult searchResult: SearchResult) {
            id = searchResult.id
            title = searchResult.title
            authors = searchResult.authors
            isbn13 = searchResult.isbn13
        }
        
        func toBookMetadata() -> BookMetadata {
            let metadata = BookMetadata(googleBooksId: id)
            metadata.title = title
            metadata.authors = authors
            metadata.bookDescription = description
            metadata.subjects = subjects
            metadata.coverImage = coverImage
            metadata.pageCount = pageCount
            metadata.publicationDate = publishedDate
            metadata.isbn13 = isbn13
            return metadata
        }
    }
    
    class SearchResultsPage {
        let searchResults: Result<[SearchResult]>
        let searchText: String?
        
        init(_ results: Result<[SearchResult]>, fromSearchText searchText: String?) {
            self.searchText = searchText
            self.searchResults = results
        }
        
        convenience init(_ results: [SearchResult], fromSearchText searchText: String) {
            self.init(Result.success(results), fromSearchText: searchText)
        }
        
        static func empty() -> SearchResultsPage {
            return SearchResultsPage(Result.success([]), fromSearchText: nil)
        }
        
        static func error(_ error: Error, fromSearchText searchText: String) -> SearchResultsPage {
            return SearchResultsPage(Result.failure(error), fromSearchText: searchText)
        }
    }
    
    class FetchResultPage {
        
        let request: Request
        let result: Result<FetchResult>
        
        init(_ result: Result<FetchResult>, fromRequest request: Request) {
            self.request = request
            self.result = result
        }
        
        convenience init(_ result: FetchResult, fromRequest request: Request) {
            self.init(Result.success(result), fromRequest: request)
        }
        
        static func empty(fromRequest request: Request) -> FetchResultPage {
            return FetchResultPage(Result.failure(GoogleErrorType.noResult), fromRequest: request)
        }
        
        static func error(_ error: Error, fromRequest request: Request) -> FetchResultPage {
            return FetchResultPage(Result.failure(error), fromRequest: request)
        }
    }
}
