//
//  books_UnitTests.swift
//  books_UnitTests
//
//  Created by Andrew Bennet on 04/11/2016.
//  Copyright © 2016 Andrew Bennet. All rights reserved.
//

import XCTest
import Foundation
import SwiftyJSON
@testable import Reading_List

class books_UnitTests: XCTestCase {
    
    var booksStore: BooksStore!
    
    override func setUp() {
        super.setUp()
        booksStore = BooksStore(storeType: .inMemory)
    }
    
    override func tearDown() {
        super.tearDown()
        booksStore = nil
    }
    
    static func days(_ count: Int) -> DateComponents {
        var component = DateComponents()
        component.day = count
        return component
    }
    
    private let yesterday = Date.startOfToday().date(byAdding: books_UnitTests.days(-1))!
    private let today = Date.startOfToday()
    private let tomorrow = Date.startOfToday().date(byAdding: books_UnitTests.days(1))!
    
    var currentTestBook = 0
    
    /// Gets a fully populated BookMetadata object. Increments the ISBN by 1 each time.
    private func getTestBookMetadata() -> BookMetadata {
        currentTestBook += 1
        let testBookMetadata = BookMetadata(googleBooksId: "ABC123\(currentTestBook)")
        testBookMetadata.title = "Test Book Title \(currentTestBook)"
        testBookMetadata.authors = "Test Book Authors \(currentTestBook)"
        testBookMetadata.bookDescription = "Test Book Description \(currentTestBook)"
        testBookMetadata.isbn13 = "1234567890\(String(format: "%03d", currentTestBook))"
        testBookMetadata.pageCount = 100 + currentTestBook
        testBookMetadata.publicationDate = Date(timeIntervalSince1970: 1488926352)
        return testBookMetadata
    }
    
    func testBookMetadataPopulates() {
        let testBookMetadata = getTestBookMetadata()
        let readingInformation = BookReadingInformation.finished(started: yesterday, finished: today)
        let readingNotes = "An interesting book..."
        
        // Create the book
        let book = booksStore.create(from: testBookMetadata, readingInformation: readingInformation, readingNotes: readingNotes)
        
        // Test that the metadata is all the same
        XCTAssertEqual(testBookMetadata.googleBooksId, book.googleBooksId)
        XCTAssertEqual(testBookMetadata.title, book.title)
        XCTAssertEqual(testBookMetadata.authors, book.authorList)
        XCTAssertEqual(testBookMetadata.bookDescription, book.bookDescription)
        XCTAssertEqual(testBookMetadata.isbn13, book.isbn13)
        XCTAssertEqual(testBookMetadata.pageCount, book.pageCount as? Int)
        XCTAssertEqual(testBookMetadata.publicationDate, book.publicationDate)
        XCTAssertEqual(readingInformation.readState, book.readState)
        XCTAssertEqual(readingInformation.startedReading, book.startedReading)
        XCTAssertEqual(readingInformation.finishedReading, book.finishedReading)
        XCTAssertEqual(readingNotes, book.notes)
    }
    
    func testReadingNotesClear() {
        let testBookMetadata = getTestBookMetadata()
        let readingInformation = BookReadingInformation.toRead()
        let readingNotes = "An interesting book (2)..."
        
        // Create the book
        let book = booksStore.create(from: testBookMetadata, readingInformation: readingInformation, readingNotes: readingNotes)
        
        // Try some updates which should not affect the notes field first; check that the notes are still there
        booksStore.update(book: book, withMetadata: testBookMetadata)
        XCTAssertEqual(readingNotes, book.notes)
        
        booksStore.update(book: book, withReadingInformation: readingInformation)
        XCTAssertEqual(readingNotes, book.notes)
        
        // Now edit the notes field
        let newNotes = "edited"
        booksStore.update(book: book, withReadingInformation: readingInformation, readingNotes: newNotes)
        XCTAssertEqual(newNotes, book.notes)
        booksStore.update(book: book, withReadingInformation: readingInformation, readingNotes: nil)
        XCTAssertNil(book.notes)
        
    }
    
    func testThatSortOrderIncrements() {
        let toReadState = BookReadingInformation.toRead()
        let book1 = booksStore.create(from: getTestBookMetadata(), readingInformation: toReadState)
        let book2 = booksStore.create(from: getTestBookMetadata(), readingInformation: toReadState)
        
        XCTAssertEqual((book1.sort as! Int) + 1, (book2.sort as! Int))
    }
    
    func testSortOrderResets() {
        let toReadState = BookReadingInformation.toRead()
        let book = booksStore.create(from: getTestBookMetadata(), readingInformation: toReadState)
        let originalSortOrder = book.sort
        
        booksStore.update(book: book, withReadingInformation: BookReadingInformation.reading(started: Date()))
        booksStore.update(book: book, withReadingInformation: BookReadingInformation.toRead())
        XCTAssertEqual(originalSortOrder, book.sort)
    }
    
    func testSortIndexRemovedWhenStarted() {
        let toReadState = BookReadingInformation.toRead()
        let book = booksStore.create(from: getTestBookMetadata(), readingInformation: toReadState)
        
        let reading = BookReadingInformation.reading(started: today)
        booksStore.update(book: book, withReadingInformation: reading)
        
        XCTAssertNil(book.sort)
    }
    
    func testToReadBookOrdering() {
        let fetchedResultsController = booksStore.fetchedResultsController(BookPredicate.readState(equalTo: .toRead), initialSortDescriptors: BooksStore.standardSortOrder)
        
        let first = booksStore.create(from: getTestBookMetadata(), readingInformation: BookReadingInformation.toRead())
        let second = booksStore.create(from: getTestBookMetadata(), readingInformation: BookReadingInformation.toRead())
        
        try! fetchedResultsController.performFetch()
        XCTAssertEqual(first, fetchedResultsController.object(at: IndexPath(item: 0, section: 0)))
        XCTAssertEqual(second, fetchedResultsController.object(at: IndexPath(item: 1, section: 0)))
    }
    
    func testReadingBookOrdering() {
        let fetchedResultsController = booksStore.fetchedResultsController(BookPredicate.readState(equalTo: .reading), initialSortDescriptors: BooksStore.standardSortOrder)
        
        let past = booksStore.create(from: getTestBookMetadata(), readingInformation: BookReadingInformation.reading(started: yesterday))
        let future = booksStore.create(from: getTestBookMetadata(), readingInformation: BookReadingInformation.reading(started: tomorrow))
        let present = booksStore.create(from: getTestBookMetadata(), readingInformation: BookReadingInformation.reading(started: today))
        
        try! fetchedResultsController.performFetch()
        XCTAssertEqual(future, fetchedResultsController.object(at: IndexPath(item: 0, section: 0)))
        XCTAssertEqual(present, fetchedResultsController.object(at: IndexPath(item: 1, section: 0)))
        XCTAssertEqual(past, fetchedResultsController.object(at: IndexPath(item: 2, section: 0)))
    }
    
    func testFinishedBookOrdering() {
        let fetchedResultsController = booksStore.fetchedResultsController(BookPredicate.readState(equalTo: .finished), initialSortDescriptors: BooksStore.standardSortOrder)
        
        let past1 = booksStore.create(from: getTestBookMetadata(), readingInformation: BookReadingInformation.finished(started: tomorrow, finished: yesterday))
        let past2 = booksStore.create(from: getTestBookMetadata(), readingInformation: BookReadingInformation.finished(started: yesterday, finished: yesterday))
        
        let future1 = booksStore.create(from: getTestBookMetadata(), readingInformation: BookReadingInformation.finished(started: tomorrow, finished: tomorrow))
        let future2 = booksStore.create(from: getTestBookMetadata(), readingInformation: BookReadingInformation.finished(started: yesterday, finished: tomorrow))
        
        let present1 = booksStore.create(from: getTestBookMetadata(), readingInformation: BookReadingInformation.finished(started: tomorrow, finished: today))
        let present2 = booksStore.create(from: getTestBookMetadata(), readingInformation: BookReadingInformation.finished(started: yesterday, finished: today))
        
        try! fetchedResultsController.performFetch()
        XCTAssertEqual(future1, fetchedResultsController.object(at: IndexPath(item: 0, section: 0)))
        XCTAssertEqual(future2, fetchedResultsController.object(at: IndexPath(item: 1, section: 0)))
        XCTAssertEqual(present1, fetchedResultsController.object(at: IndexPath(item: 2, section: 0)))
        XCTAssertEqual(present2, fetchedResultsController.object(at: IndexPath(item: 3, section: 0)))
        XCTAssertEqual(past1, fetchedResultsController.object(at: IndexPath(item: 4, section: 0)))
        XCTAssertEqual(past2, fetchedResultsController.object(at: IndexPath(item: 5, section: 0)))
    }
    
    func testIsbnDetection() {
        let testBook = getTestBookMetadata()
        XCTAssertNil(booksStore.getIfExists(isbn: testBook.isbn13))
        booksStore.create(from: testBook, readingInformation: BookReadingInformation.toRead())
        XCTAssertNotNil(booksStore.getIfExists(isbn: testBook.isbn13))
    }
    
    func testHumanisedDateString() {
        XCTAssertEqual("Today", today.toPrettyString(short: true))
        XCTAssertEqual("Today", today.toPrettyString(short: false))
    }
    
    func testIsbnParsing() {
        // Wrong length
        XCTAssertNil(Isbn13.tryParse(inputString: "12345"))
        // Wrong prefix
        XCTAssertNil(Isbn13.tryParse(inputString: "1234567891023"))
        // Wrong check digit
        XCTAssertNil(Isbn13.tryParse(inputString: "9781781100263"))
        XCTAssertNil(Isbn13.tryParse(inputString: "978-1-78110-026-3"))
        
        // Correct
        XCTAssertNotNil(Isbn13.tryParse(inputString: "9781781100264"))
        XCTAssertNotNil(Isbn13.tryParse(inputString: "978-1-78110-026-4"))
    }
    
    func testCreatedDateSet() {
        let beforeDate = Date()
        let newBook = booksStore.create(from: getTestBookMetadata(), readingInformation: BookReadingInformation.finished(started: tomorrow, finished: yesterday))
        let afterDate = Date()
        XCTAssertEqual(newBook.createdWhen.compare(beforeDate), ComparisonResult.orderedDescending)
        XCTAssertEqual(newBook.createdWhen.compare(afterDate), ComparisonResult.orderedAscending)
    }
    
    func testGoogleBooksFetchParsing() {
        let bundle = Bundle(for: type(of: self))
        let path = bundle.path(forResource: "GoogleBooksFetchResult", ofType: "json")!
        let json = JSON(NSData(contentsOfFile: path)!)
        
        let parseResult = GoogleBooks.Parser.parseFetchResults(json)
        XCTAssertNotNil(parseResult)
        XCTAssertEqual("The Sellout", parseResult!.title)
        XCTAssertEqual("Paul Beatty", parseResult!.authors)
        XCTAssertEqual("Fiction", parseResult!.subjects[0])
        XCTAssertEqual("Satire", parseResult!.subjects[1])
        XCTAssertEqual(304, parseResult!.pageCount)
        XCTAssertEqual("9781786070166", parseResult!.isbn13)
        XCTAssertNotNil(parseResult!.description)
    }
    
    func testGoogleBooksSearchParsing() {
        let bundle = Bundle(for: type(of: self))
        let path = bundle.path(forResource: "GoogleBooksSearchResult", ofType: "json")!
        let json = JSON(NSData(contentsOfFile: path)!)
        
        let parseResult = GoogleBooks.Parser.parseSearchResults(json)
        // There are 3 results with no author, which we expect to not show up in the list. Hence: 37.
        XCTAssertEqual(37, parseResult.count)
        for result in parseResult {
            // Everything must have an ID
            XCTAssertNotNil(result.id)
        }
        
        let resultsWithIsbn = parseResult.filter{$0.isbn13 != nil}.count
        XCTAssertEqual(29, resultsWithIsbn)
        
        let resultsWithCover = parseResult.filter{$0.thumbnailCoverUrl != nil}.count
        XCTAssertEqual(32, resultsWithCover)
    }
    
    func testCreateExistingSubjects() {
        let sub1 = booksStore.getOrCreateSubject(withName: "Subject 1")
        let sub2 = booksStore.getOrCreateSubject(withName: "Subject 1")
        XCTAssertEqual(sub1.objectID, sub2.objectID)
        
        XCTAssertEqual(1, booksStore.getAllSubjects().count)
    }
    
    func testCreateNewSubjects() {
        let sub1 = booksStore.getOrCreateSubject(withName: "Subject 1")
        let sub2 = booksStore.getOrCreateSubject(withName: "Subject 2")
        XCTAssertNotEqual(sub1.objectID, sub2.objectID)
        
        XCTAssertEqual(2, booksStore.getAllSubjects().count)
    }
    
    func testAddSubjects() {
        let newBook = booksStore.create(from: getTestBookMetadata(), readingInformation: BookReadingInformation.toRead())
        let sub1 = booksStore.getOrCreateSubject(withName: "Subject 1")
        let sub2 = booksStore.getOrCreateSubject(withName: "Subject 2")
        newBook.addSubjects(NSOrderedSet(array: [sub1, sub2]))
        booksStore.save()
        
        XCTAssertEqual(2, newBook.subjects.count)
        XCTAssertEqual("Subject 1", (newBook.subjects[0] as! Subject).name)
        XCTAssertEqual("Subject 2", (newBook.subjects[1] as! Subject).name)
        
        newBook.removeSubjects(NSSet(array: [sub1, sub2]))
        newBook.addSubjects(NSOrderedSet(array: [sub2, sub1]))
        booksStore.save()
        XCTAssertEqual(2, newBook.subjects.count)
        XCTAssertEqual("Subject 2", (newBook.subjects[0] as! Subject).name)
        XCTAssertEqual("Subject 1", (newBook.subjects[1] as! Subject).name)
    }
    
    func testSubjectAutomaticDeletion() {
        let book1Metadata = getTestBookMetadata()
        book1Metadata.subjects = ["Subject 1"]
        let newBook1 = booksStore.create(from: book1Metadata, readingInformation: BookReadingInformation.toRead())
        
        let book2Metadata = getTestBookMetadata()
        book2Metadata.subjects = ["Subject 1"]
        let newBook2 = booksStore.create(from: book2Metadata, readingInformation: BookReadingInformation.toRead())
        
        booksStore.save()

        XCTAssertEqual(1, booksStore.getAllSubjects().count)
        
        booksStore.deleteBook(newBook1)
        booksStore.save()
        XCTAssertEqual(1, booksStore.getAllSubjects().count)
        
        booksStore.deleteBook(newBook2)
        booksStore.save()
        XCTAssertEqual(0, booksStore.getAllSubjects().count)
    }
}
