//
//  solver.swift
//  GPSudokuSolver
//
//  Created by Gord Parke on 5/24/18.
//  Copyright © 2018 Gord Parke. All rights reserved.
//

import Foundation

typealias Bitfield = UInt16
typealias PossibilityMatrix = Matrix<Bitfield>

// Possible numbers in a 9x9 matrix
let numberMask: Bitfield = 0x01FF

extension Bitfield {
    var allBitsSet: Bool { return self == Bitfield.max }
    var singleBitSet: Bool {
        return (self != 0) && (self & (self - 1) == 0) // This latter operation essentially zeros the rightmost set bit
    }
    var singleBitUnset: Bool {
        return (self != Bitfield.max) && (self | (self + 1) == Bitfield.max)
    }
}


/// If we find that a particular number has to go in a particular cell, this method can be used to update the board's possbility matrix accordingly.
fileprivate func updateKnownNumber(withBitfieldComplement bc: Bitfield, at index: CellIndex, in possibilityMatrix: inout PossibilityMatrix) {
    
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
fileprivate func cellEliminationPass(through possibilityMatrix: PossibilityMatrix) throws -> PossibilityMatrix  {
    
    // Create an update matrix
    var updateBitmasks = try possibilityMatrix.map { (cellIndex, value) in
        guard value != 0 else { throw SolverError.internalInconsistency }
        
        // Short circuit with no update if we already know a value for this cell
        guard value.singleBitSet == false else { return 0 }
        
        // Helper method that implements code common to row, columns, and squares. It looks for a number that can only go in one spot.
        // - returns: if such a number exists, it returns the complement to that numbers possibility bitfield, and nil otherwise.
        func checkForSinglePossibility(in complement: [Bitfield]) throws -> Bitfield? {
            let complementField = complement.reduce(~numberMask, |)
            if complementField.allBitsSet {
                return nil
            } else {
                // Check there is only one 0; if there are multiple, we must throw an error because we cannot put more than one number in the same cell!
                guard complementField.singleBitUnset else { throw SolverError.eliminationInconsistency }
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


fileprivate func solveSudoku(with possiblityMatrix: PossibilityMatrix) throws -> PossibilityMatrix {
    var mP = possiblityMatrix
    
    // Now iterate by doing elimination passes until one has no effect.
    var iterCount = 0
    var prevMP: PossibilityMatrix?
    repeat {
        prevMP = mP
        mP = try cellEliminationPass(through: mP)
        
        guard mP.hasZeroCell == false else { throw SolverError.eliminationInconsistency }
        
        iterCount += 1
        if iterCount > 1000 { throw SolverError.maxIter }
    } while prevMP != mP
    
    // Short circuit if matrix is solved, but most times we'll have to start recursively guessing.
    guard let firstUnknownCell = mP.firstUnknownCell else { return mP }
    
    var guessStack: [Bitfield] = []
    
    // Find set bits in bitfield to build gueses
    var guessBuilder = firstUnknownCell.bitfield
    while guessBuilder != 0 {
        guessStack.append(guessBuilder)
        guessBuilder = guessBuilder & (guessBuilder - 1) // Unset rightmost bit.
    }
    
    // We want just one bit set for all guesses, so work backwards and fix the earlier ones.
    var mask = numberMask
    for i in (0..<guessStack.count).reversed() {
        guessStack[i] &= mask
        mask &= ~guessStack[i]
    }
    
    for guess in guessStack {
        var guessMatrix = mP
        guessMatrix[firstUnknownCell.index] = guess
        
        do { return try solveSudoku(with: guessMatrix) }
        catch SolverError.eliminationInconsistency { continue }
        catch SolverError.guessingFailed { continue }
    }
    
    // If we have gotten to here, guessing failed.
    throw SolverError.guessingFailed
}

func solveSudoku(_ sudoku: Sudoku) throws -> Sudoku {
    
    // The possibilty matrix is a 9x9 array of UInt16s that maps directly to the Sudoku board. The position of set bits indicate what numbers are possible in that cell.  For example, a value of 00010010 says that the cell can only be either a 2 or 5.
    var mP = Matrix([[Bitfield]](repeating: [Bitfield](repeating: numberMask, count: 9), count: 9)) // Initialize such that all numbers are possible for every cell.
    
    // Now update the matrices according to the initial values in the sudoku.
    for i in 0..<9 {
        for j in 0..<9 {
            if let value = sudoku[i][j] {
                let bitRepresentation = 1 << (value - 1)
                updateKnownNumber(withBitfieldComplement: ~bitRepresentation, at: (i,j), in: &mP)
            }
        }
    }
    
//     Now iterate by doing a number elimination pass, then cell elimination pass, until neither has any effect.
    mP = try solveSudoku(with: mP)
    
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

// MARK: Matrix Extensions
extension Matrix where T == Bitfield {
   
    var firstUnknownCell: (index: CellIndex, bitfield: Bitfield)? {
        for i in 0..<self.storage.count {
            for j in 0..<self.storage[i].count {
                let idx = (i,j)
                if self[idx].singleBitSet == false {
                    return (idx, self[idx])
                }
            }
        }
        return nil
    }
    
    var hasZeroCell: Bool {
        for i in 0..<self.storage.count {
            for j in 0..<self.storage[i].count {
                if self[(i,j)] == 0 { return true }
            }
        }
        return false
    }
}

// MARK: Errors
enum SolverError: Error {
    case maxIter
    case noSolutionFound
    case internalInconsistency
    
    case eliminationInconsistency
    case guessingFailed
}


