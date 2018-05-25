//
//  solver.swift
//  GPSudokuSolver
//
//  Created by Gord Parke on 5/24/18.
//  Copyright © 2018 Gord Parke. All rights reserved.
//

import Foundation

// Possible numbers in a 9x9 matrix
let numberMask: UInt16 = 0x01FF

extension UInt16 {
    var allBitsSet: Bool { return self == UInt16.max }
    
    var singleBitSet: Bool {
        return (self != 0) && (self & (self - 1) == 0) // This latter operation essentially zeros the rightmost set bit
    }
    
    var singleBitUnset: Bool {
        return (self != UInt16.max) && (self | (self + 1) == UInt16.max)
    }
}

/// If we find that a particular number has to go in a particular cell, this method can be used to update the board's possbility matrix accordingly.
func updateKnownNumber(withBitfieldComplement bc: UInt16, at index: Matrix.CellIndex, in possibilityMatrix: inout Matrix) {
    
    // Set bits associated with the possibility of this sudoku number to 0 in its row, column, and square.
    var newMatrix = possibilityMatrix
        .mapRow(containing: index) { $0 & bc }
        .mapColumn(containing: index) { $0 & bc }
        .mapSquare(containing: index) { $0 & bc }
    
    // A single bit set at the cell's index, which indicates this number is the only possibility.
    newMatrix[index] = ~bc
    
    possibilityMatrix = newMatrix
}

/// For each cell, this function looks through the other cells in row, column, and square, and identifies if there are any numbers that can't go anywhere else but the current cell.
func cellEliminationPass(through possibilityMatrix: Matrix) throws -> Matrix  {
    
    // Create an update matrix
    var updateBitmasks = try possibilityMatrix.map { (cellIndex, value) in
        guard value != 0 else { throw SolverError.internalInconsistency }
        
        // Short circuit with no update if we already know a value for this cell
        guard value.singleBitSet == false else { return 0 }
        
        // Helper method that implements code common to row, columns, and squares. It looks for a number that can only go in one spot.
        // - returns: if such a number exists, it returns the complement to that numbers possibility bitfield, and nil otherwise.
        func checkForSinglePossibility(in complement: [UInt16]) throws -> UInt16? {
            let complementField = complement.reduce(~numberMask, |)
            if complementField.allBitsSet {
                return nil
            } else {
                // Check there is only one 0; if there are multiple, we must throw an error because we cannot put more than one number in the same cell!
                guard complementField.singleBitUnset else { throw SolverError.cellEliminationError }
                return complementField
            }
        }
        
        // Check row complement
        var row = possibilityMatrix.row(containing: cellIndex)
        row[cellIndex.1] = 0 // Ignore the current cell
        if let knownBitfield = try checkForSinglePossibility(in: row) { return knownBitfield }
        
        // Check column complement
        var col = possibilityMatrix.column(containing: cellIndex)
        col[cellIndex.0] = 0 // Ignore the current cell
        if let knownBitfield = try checkForSinglePossibility(in: col) { return knownBitfield }
        
        // Check square complement
        var square = possibilityMatrix.square(containing: cellIndex)
        square[3*(cellIndex.0 % 3) + (cellIndex.1 % 3)] = 0 // Ignore the current cell
        if let knownBitfield = try checkForSinglePossibility(in: square) { return knownBitfield }
        
        // No update
        return 0
    }
    
    // Loop through update matrix and perform updates
    var newPossibilityMatrix = possibilityMatrix
    updateBitmasks.forEach{ index, bitmask in
        guard bitmask != 0 else { return }
        updateKnownNumber(withBitfieldComplement: bitmask, at: index, in: &newPossibilityMatrix)
    }
    
    return newPossibilityMatrix
}


func solve(_ sudoku: Sudoku) throws -> Sudoku {
    
    // The possibilty matrix is a 9x9 array of UInt16s that maps directly to the Sudoku board. The position of set bits indicate what numbers are possible in that cell.  For example, a value of 00010010 says that the cell can only be either a 2 or 5.
    var mP = Matrix([[UInt16]](repeating: [UInt16](repeating: numberMask, count: 9), count: 9)) // Initialize such that all numbers are possible for every cell.
    
    // Now update the matrices according to the initial values in the sudoku.
    for i in 0..<9 {
        for j in 0..<9 {
            if let value = sudoku[i][j] {
                let bitRepresentation = 1 << (value - 1)
                updateKnownNumber(withBitfieldComplement: ~bitRepresentation, at: (i,j), in: &mP)
            }
        }
    }
    
    // Now iterate by doing a number elimination pass, then cell elimination pass, until neither has any effect.
    var iterCount = 0
    var prevMP: Matrix?
    repeat {
        prevMP = mP
        mP = try cellEliminationPass(through: mP)
        
        iterCount += 1
        if iterCount > 1000 { throw SolverError.maxIter }
    } while prevMP != mP
    
    
    // CHeck if fully solved, else throw error.
    let solvedSudoku = try mP.map { (_, value) -> UInt16 in
//        guard singleBitSet == false else { throw SolverError.noSolutionFound }
        guard value.singleBitSet else { return 0 }
        guard value != 0 else { throw SolverError.internalInconsistency }
        
        
        // Look for the set bit to get the sudoku number
        var sudokuNumber: UInt16 = 1
        var shiftedValue = value
        while (shiftedValue & 1) == 0 {
            sudokuNumber += 1
            shiftedValue >>= 1
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


