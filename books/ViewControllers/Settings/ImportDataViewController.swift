//
//  ImportDataViewController.swift
//  books
//
//  Created by Andrew Bennet on 08/04/2017.
//  Copyright © 2017 Andrew Bennet. All rights reserved.
//

import Foundation
import UIKit
import Eureka
import SVProgressHUD

class ImportDataViewController : FormViewController, UIDocumentPickerDelegate, UIDocumentMenuDelegate {
    
    private let downloadImagesKey = "downloadImages"
    private let selectDocumentKey = "selectDocument"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let downloadImagesSection = Section(footer: "If enabled, book covers will be downloaded where the import document has either an ISBN-13 or a Google Books ID.")
        downloadImagesSection.append(SwitchRow(downloadImagesKey) {
            $0.title = "Download Images"
            $0.value = true
        })
        form.append(downloadImagesSection)
        
        let headerNames = ["Google Books ID", "ISBN-13", "Title", "Author", "Page Count", "Publication Date", "Description", "Subjects", "Started Reading", "Finished Reading", "Notes"]
        func bulletPointedItem(_ item: String) -> String { return "  \u{2022} \(item)" }
        
        let selectDocumentSection = Section(footer: "Import books from a CSV file. Duplicates (by ISBN or Google Books ID) and invalid entries will be skipped.\n\n"
                + "The CSV file should have the following headers:\n\n"
                + headerNames.map{ bulletPointedItem($0) }.joined(separator: "\n"))
    
        selectDocumentSection.append(ButtonRow(selectDocumentKey) {
            $0.title = "Import Books"
            $0.onCellSelection{ [unowned self] cell,_ in
                self.requestImport(cell: cell)
            }
        })
        form.append(selectDocumentSection)
    }
    
    func requestImport(cell: ButtonCellOf<String>) {
        let documentImport = UIDocumentMenuViewController(documentTypes: ["public.comma-separated-values-text"], in: .import)
        documentImport.delegate = self
        if let popPresenter = documentImport.popoverPresentationController {
            popPresenter.sourceRect = cell.contentView.bounds
            popPresenter.sourceView = cell.contentView
            popPresenter.permittedArrowDirections = .up
        }
        self.present(documentImport, animated: true)
    }
    
    func documentMenu(_ documentMenu: UIDocumentMenuViewController, didPickDocumentPicker documentPicker: UIDocumentPickerViewController) {
        documentPicker.delegate = self
        self.present(documentPicker, animated: true, completion: nil)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        SVProgressHUD.show(withStatus: "Importing")
        
        // We may want to download book cover images
        let shouldSupplementBooks = form.values()[downloadImagesKey] as! Bool
        
        BookImporter(csvFileUrl: url, supplementBookCover: shouldSupplementBooks, supplementBookMetadata: false, missingHeadersCallback: {
            
        }, callback: {
            importedCount, duplicateCount, invalidCount in
            var statusMessage = "\(importedCount) books imported."
            
            if duplicateCount != 0 {
                statusMessage += " \(duplicateCount) rows ignored due pre-existing data."
            }
            
            if invalidCount != 0 {
                statusMessage += " \(invalidCount) rows ignored due to invalid data."
            }
            SVProgressHUD.showInfo(withStatus: statusMessage)
        }).StartImport()
    }

}
