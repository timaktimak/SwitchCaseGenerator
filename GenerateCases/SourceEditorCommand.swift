//
//  SourceEditorCommand.swift
//  GenerateCases
//
//  Created by Timur Galimov on 24/12/2016.
//  Copyright © 2016 Timur Galimov. All rights reserved.
//

import Foundation
import XcodeKit

extension String {
    
    var prepared: String? {
        let line = trimmingCharacters(in: .whitespacesAndNewlines)
        return line.isEmpty ? nil : line
    }
}

private class CasesExtractor {
    
    private static func getSelectedLinesIndexes(fromBuffer buffer: XCSourceTextBuffer) -> [Int] {
        
        var result: [Int] = []
        for range in buffer.selections {
            guard let range = range as? XCSourceTextRange else { preconditionFailure() }
            for lineNumber in range.start.line...range.end.line {
                result.append(lineNumber)
            }
        }
        return result
    }
    
    static func extractCases(fromBuffer buffer: XCSourceTextBuffer) -> [String] {
        var result: [String] = []
        let idx = getSelectedLinesIndexes(fromBuffer: buffer)
        for index in idx {
            guard let line = buffer.lines[index] as? String else { preconditionFailure() }
            guard let l = line.prepared else { continue }
            let caseStr = "case"
            if l.hasPrefix(caseStr) {
                let index = l.index(l.startIndex, offsetBy: caseStr.characters.count)
                let dropCase = l.substring(from: index)
                let cases = dropCase.components(separatedBy: ",")
                result.append(contentsOf: cases.map { $0.trimmingCharacters(in: .whitespaces) })
            }
        }
        return result
    }
}

class SourceEditorCommand: NSObject, XCSourceEditorCommand {
    
    private func generateSwitch(fromCases cases: [String], tabWidth: Int) -> String {
        let indent = String(repeating: " ", count: tabWidth)
        let casesStr = cases.map { "\(indent)case .\($0):\n\(indent)\(indent)break\n" }.joined()
        return "\n\(indent)switch <#value#> {\n\(casesStr)\(indent)}\n"
    }
    
    private func lastSelectedLine(fromBuffer buffer: XCSourceTextBuffer) -> Int? {
        return (buffer.selections.lastObject as? XCSourceTextRange)?.end.line
    }
    
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        
        defer { completionHandler(nil) } // error looks ugly, just do nothing in case of an error
        
        guard invocation.buffer.contentUTI == "public.swift-source" else { return }
        guard let lineIndex = lastSelectedLine(fromBuffer: invocation.buffer) else { return }
        
        let cases = CasesExtractor.extractCases(fromBuffer: invocation.buffer)
        
        guard cases.count > 0 else { return }
        
        let str = generateSwitch(fromCases: cases, tabWidth: invocation.buffer.tabWidth)
        invocation.buffer.lines.insert(str, at: lineIndex + 1)
        
        // select the inserted code
        let start = XCSourceTextPosition(line: lineIndex + 2, column: 0)
        let end = XCSourceTextPosition(line: lineIndex + 2 * cases.count + 4, column: 0)
        invocation.buffer.selections.setArray([XCSourceTextRange(start: start, end: end)])
    }
}
