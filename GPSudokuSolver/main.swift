//
//  main.swift
//  GPSudokuSolver
//
//  Created by Gord Parke on 5/24/18.
//  Copyright © 2018 Gord Parke. All rights reserved.
//

import Foundation

let usageString = """
Usage: You can either enter your own sudoku or fetch a random one from the internet.
- To use your own, enter the sudoku values in row-major order using 0's for unknown values.  Like '0 1 0 4 0 0 6 ...'
- To fetch a random one from the internet, run with no command line arguments.
"""


fileprivate func startSolving(_ sudoku: Sudoku) {
    do {
        print("Solving sudoku:\n\(String(sudoku))")
        let startDate = Date()
        let solution = try solveSudoku(sudoku)
        print("Solved sudoku in \(Int(Date().timeIntervalSince(startDate)*1000)) ms:\n\(String(solution))")
        exit(1)
    } catch {
        print("Failed solving sudoku with \(error)")
        exit(0)
    }
}


if CommandLine.arguments.count == 1 {
    print("Fetching sudoku from sugoku.herokuapp.com....")
    fetchSudokuThen(startSolving)
} else {

    guard CommandLine.arguments.count == 82 else {
        print(usageString)
        exit(1)
    }
    
    // Parse sudoku from command line input
    var rows :[[UInt16?]] = []
    for i in 0..<9 {
        let rowStrings = CommandLine.arguments[(9*i + 1) ..< (9*(i+1) + 1)]
        let row = rowStrings.map{ (str: String) -> UInt16? in
            guard let numericValue = UInt16(str) else {
                print("Unable to parse input argument \(str)\n\(usageString)")
                exit(1)
            }
            return numericValue != 0 ? numericValue : nil
        }
        rows.append(row)
    }
    
    startSolving(rows)
}

RunLoop.main.run()


