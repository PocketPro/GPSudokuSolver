//
//  solver.swift
//  GPSudokuSolver
//
//  Created by Gord Parke on 5/24/18.
//  Copyright © 2018 Gord Parke. All rights reserved.
//

import Foundation

typealias StateMatrices = (possibilites: Matrix, knownValues: Matrix)

let numberMask: UInt16 = 0x01FF

/// For each cell, this function looks for known numbers in the same row, col, and square, and eliminates those from the set of possibilities.
func numberEliminationPass(_ matrices: StateMatrices) throws -> StateMatrices {
    var mKnownValues = matrices.knownValues
    
    let updatedPossibilities = try matrices.possibilites.map{ (cellIndex, value) in
        
        // Short circuit if we already know this cell
        guard mKnownValues[cellIndex].allBitsSet else { return value }
        
        // Eliminate numbers for this cell based on values we know in its row, column, and square
        let row = mKnownValues.row(containing: cellIndex).reduce(numberMask, &)
        let col = mKnownValues.column(containing: cellIndex).reduce(numberMask, &)
        let square = mKnownValues.square(containing: cellIndex).reduce(numberMask, &)
        let combined = row & col & square
        
        guard combined != 0 else { throw SolverError.numberEliminationError }
        
        // If there is only one bit set, update the known values.
        if combined & (combined - 1) == 0 {   // (this bitwise operation unsets the rightmost bit. So if there was only 1 bit set, the result will be 0. )
            mKnownValues[cellIndex] = ~combined
        }
        
        return combined
    }
    
    return (updatedPossibilities, mKnownValues)
}

/// For each cell, this function looks through the other cells in row, column, and square, and identifies if there are any numbers that can't go anywhere else but the current cell.
func cellEliminationPass(_ matrices: StateMatrices) throws -> StateMatrices {
    let mKnownValues = matrices.knownValues
    
    // Scan through known values and update
    var newKnownValues = try matrices.knownValues.map { (cellIndex, value) in
        
        // Short circuit if we already know a value for this cell
        guard value.allBitsSet else { return value }
        
        // Helper method that looks through a row, column, or square for a number that can only go in one spot.
        // If such a number exists, it will have a 0 in the appropriate bit position. We can use this to update the known values matrix directly.
        func checkForSinglePossibility(in complement: [UInt16]) throws -> UInt16? {
            let otherPositionPossibilities = complement.reduce(~numberMask, |)
            if otherPositionPossibilities.allBitsSet {
                return nil
            } else {
                // Check there is only one 0; if there are multiple, we must throw an error because we cannot put more than one number in the same cell!
                guard (otherPositionPossibilities | (otherPositionPossibilities + 1)).allBitsSet else {
                    throw SolverError.cellEliminationError
                }
                return otherPositionPossibilities
            }
        }
        
        // Check row
        var row = matrices.possibilites.row(containing: cellIndex)
        row[cellIndex.1] = 0 // Drop the current cell
        if let knownBitfield = try checkForSinglePossibility(in: row) { return knownBitfield }
        
        // Check row:
        var col = matrices.possibilites.column(containing: cellIndex)
        col[cellIndex.0] = 0 // Drop the current cell
        if let knownBitfield = try checkForSinglePossibility(in: col) { return knownBitfield }
        
        // Check square
        var square = matrices.possibilites.square(containing: cellIndex)
        square[3*(cellIndex.0 % 3) + (cellIndex.1 % 3)] = 0 // Drop the current cell
        if let knownBitfield = try checkForSinglePossibility(in: square) { return knownBitfield }
        
        return value
    }
    
    return (matrices.possibilites, newKnownValues)
}

func solve(_ sudoku: Sudoku) throws -> Sudoku {
    
    // The possibilty matrix is a 9x9 array of UInt16s that maps directly to the Sudoku board. The position of set bits indicate what numbers are possible in that cell.  For example, a value of 00010010 says that the cell can only be either a 2 or 5.
    var mP = Matrix([[UInt16]](repeating: [UInt16](repeating: numberMask, count: 9), count: 9)) // Initialize such that all numbers are possible for every cell.
    
    // The known matrix is also a 9x9 array of UInt16s that maps directly to the Sudoku board. If the number for a cell is known on the board, the cell in this matrix should have a 0 bit at that position, and 1's elsewhere.  If the cell isn't known, it should be all 1's.  For example, 11110111 indicates that the value for a particular cell is known, and that it is 4.
    var mK = Matrix([[UInt16]](repeating: [UInt16](repeating: UInt16.max, count: 9), count: 9)) // Initialize as if we knew no values.
    
    // Now update the matrices according to the initial values in the sudoku.
    for i in 0..<9 {
        for j in 0..<9 {
            if let value = sudoku[i][j] {
                let bitRepresentation = 1 << (value - 1)
                mP[(i,j)] = bitRepresentation
                mK[(i,j)] = ~bitRepresentation
            }
        }
    }
    
    // Now iterate by doing a number elimination pass, then cell elimination pass, until neither has any effect.
    var iterCount = 0
    var wasUpdated = false
    repeat {
        let prevMatrices = (p: mP, k: mK)
        (mP, mK) = try cellEliminationPass(numberEliminationPass((mP, mK)))
        wasUpdated = (prevMatrices.p != mP || prevMatrices.k != mK)
        
        iterCount += 1
        if iterCount > 1000 { throw SolverError.maxIter }
    } while wasUpdated
    
    
    // CHeck if fully solved, else throw error.
    let solvedSudoku = try mK.map { (_, value) -> UInt16 in
//        guard value.allBitsSet == false else { throw SolverError.noSolutionFound }
                guard value.allBitsSet == false else { return 0 }

        
        // Flip the bits in value and look for the first set bit.
        var sudokuNumber: UInt16 = 1
        var shiftedValue = ~value
        while (shiftedValue & 1) == 0 {
            sudokuNumber += 1
            shiftedValue >>= 1
        }
        
        // Assert that we only had one zero...
        guard (shiftedValue>>1) == 0 else {
            throw SolverError.internalInconsistency
        }
        
        return sudokuNumber
    }
    
    return solvedSudoku.storage
}



enum SolverError: Error {
    case maxIter
    case noSolutionFound
    case internalInconsistency
    
    case cellEliminationError
    case numberEliminationError
}

extension UInt16 {
    var allBitsSet: Bool { return self == UInt16.max }
}

