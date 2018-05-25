//
//  helpers.swift
//  GPSudokuSolver
//
//  Created by Gord Parke on 5/24/18.
//  Copyright © 2018 Gord Parke. All rights reserved.
//

import Foundation

typealias Sudoku = [[UInt16?]]

func fetchSudokuThen(_ callback: @escaping (Sudoku) -> ()) {
    
    let url = URL(string: "https://sugoku.herokuapp.com/board?difficulty=easy")!
    let downloadTask = URLSession.shared.dataTask(with: url) { (data, _, error) in
        guard let data = data else { print("Unable to fetch sudoku with error: \(error!)"); return }
        
        struct Response: Codable {
            let board: [[UInt16]]
        }
        
        do {
            let response = try JSONDecoder().decode(Response.self, from: data)
            let parsedSudoku = response.board.map{ $0.map{ $0 == 0 ? nil : $0 } }
            callback(parsedSudoku)
        } catch {
            print("Unable to parse sudoku with error: \(error)")
        }
    }
    
    downloadTask.resume()
}

extension String {
    
    init(_ sudoku: Sudoku) {
        
        func rowString(_ r: [UInt16?]) -> String {
            let segments = [r[0..<3], r[3..<6], r[6..<9]]
            
            func segmentToString(_ segment: ArraySlice<UInt16?>) -> String {
                return segment.map{ $0.map{ String($0) } ?? " " }.joined(separator: " ")
            }
            
            return segments.map(segmentToString).joined(separator: " | ")
        }
        
        let rowSegments = [sudoku[0..<3], sudoku[3..<6], sudoku[6..<9]]
        let str = rowSegments.map{ segment in
            segment.map(rowString).joined(separator: "\n")
            }.joined(separator: "\n---------------------\n")
        
        self.init(str)
    }
    
}
