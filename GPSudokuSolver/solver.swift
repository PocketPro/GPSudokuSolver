//
//  solver.swift
//  GPSudokuSolver
//
//  Created by Gord Parke on 5/24/18.
//  Copyright © 2018 Gord Parke. All rights reserved.
//

import Foundation

/// The set of functions below solve Sudokus using a layered strategy. The first line of attack is to fill in cells using an elimination process, looking for a cell that only hold a single potential number, or a number that can only go in a single cell in a given row, column, or square. This is sometimes sufficient to solve the puzzle alone, especially for easier problems. In general, however, we need to resort to a recursive guessing strategy. I believe this may be true for any Sudoku solver, since some problems have multiple solutions.

/// The elimination process works by keeping a matrix of bitfields for each cell in the Sudoku.  Each bit in the bitfield indicates the possibility of that cell holding a potential number. For example, a value of 0...00010010 means the cell can only hold a 2 or 5.  This is handy becuase it allows us to perform boolean operations on all possible numbers in a single operation.  These bitmasks can be updated in two ways.  First, if we determine that a particular value has to go in a specific cell, we can mask all other cells in the row, column, and square with its bitfield. That excludes the possibility of that number from those cells. Second, we can take a cell, bitwise OR the bitfields for all _other_ cells in its row, column, or square together, and take the complement of the result.  If this bitfield has a single bit set (which we can determine efficiently), then we have found a number that can _only_ go in that cell.

// MARK: - Types
typealias Bitfield = UInt16
typealias PossibilityMatrix = Matrix<Bitfield>

extension Bitfield {
    var allBitsSet: Bool { return self == Bitfield.max }
    var singleBitSet: Bool {
        return (self != 0) && (self & (self - 1) == 0) // This latter operation essentially zeros the rightmost set bit
    }
    var singleBitUnset: Bool {
        return (self != Bitfield.max) && (self | (self + 1) == Bitfield.max)
    }
    static let mask: Bitfield = 0x01FF // Possible number positions in a 9x9 matrix
}

// MARK: - Interface
func solveSudoku(_ sudoku: Sudoku) throws -> Sudoku {
    
    // The possibilty matrix is a 9x9 array of UInt16s that maps directly to the Sudoku board. The position of set bits indicate what numbers are possible in that cell.
    // For example, a value of 0...00010010 says that the cell can only be either a 2 or 5.
    var possibilityMatrix = Matrix([[Bitfield]](repeating: [Bitfield](repeating: Bitfield.mask, count: 9), count: 9)) // Initialize such that all numbers are possible for every cell.
    
    // Now update the matrices according to the initial values in the sudoku.
    for i in 0..<9 {
        for j in 0..<9 {
            if let value = sudoku[i][j] {
                let bitRepresentation = 1 << (value - 1)
                updateKnownCell(withBitfieldComplement: ~bitRepresentation, at: (i,j), in: &possibilityMatrix)
            }
        }
    }
    
    guard possibilityMatrix.representsValidSudoku else { throw SolverError.invalidSudoku }
    
    try solvePossibilityMatrix(&possibilityMatrix)
    
    guard possibilityMatrix.hasUnknownCell == false  else { throw SolverError.noSolutionFound }
    guard possibilityMatrix.hasZeroCell == false else { throw SolverError.internalInconsistency }
    guard possibilityMatrix.representsValidSudoku else { throw SolverError.internalInconsistency } // We should have checked input already, so this is an internal inconsistency
    
    return possibilityMatrix
        .map { (_, value) -> UInt16 in
            
            // Determine which bit is set in the bitfield to get the sudoku number
            var sudokuNumber: UInt16 = 1
            var shiftedValue = value
            while (shiftedValue & 1) == 0 {
                sudokuNumber += 1
                shiftedValue >>= 1
            }
            
            return sudokuNumber
        }
        .storage
}

// MARK: - Solving

fileprivate func solvePossibilityMatrix(_ possiblityMatrix: inout PossibilityMatrix) throws {
    
    // Iterate through possibility matrix multiple times, eliminating possibilities at every pass. Stop when a pass has no effect.
    var iterCount = 0
    var prevMP: PossibilityMatrix?
    repeat {
        prevMP = possiblityMatrix
        try cellEliminationPass(through: &possiblityMatrix)
        
        guard possiblityMatrix.hasZeroCell == false else { throw SolverError.eliminationInconsistency }
        guard possiblityMatrix.representsValidSudoku else { throw SolverError.eliminationInconsistency }

        iterCount += 1
        if iterCount > 1000 { throw SolverError.maxIter }
    } while prevMP != possiblityMatrix
    
    
    // Short circuit if matrix is solved...
    guard let firstUnknownCell = possiblityMatrix.firstUnknownCell else { return }
    
    // ...but most times we'll have to start recursively guessing.
    var guessStack: [Bitfield] = []
    
    // Find the set bits in possibility bitfield in order to build gueses
    var guessBuilder = firstUnknownCell.bitfield
    while guessBuilder != 0 {
        guessStack.append(guessBuilder)
        guessBuilder = guessBuilder & (guessBuilder - 1) // Unset rightmost bit.
    }
    
    // We want just one bit set for all guesses, so work backwards and fix the earlier ones.
    var mask = Bitfield.mask
    for i in (0..<guessStack.count).reversed() {
        guessStack[i] &= mask
        mask &= ~guessStack[i]
    }
    
    // Guess, and try again if we encounter a solving error.
    for guess in guessStack {
        var guessMatrix = possiblityMatrix
        guessMatrix[firstUnknownCell.index] = guess
        
        do {
            try solvePossibilityMatrix(&guessMatrix)
            possiblityMatrix = guessMatrix
            return
        }
        catch SolverError.eliminationInconsistency { continue }
        catch SolverError.guessingFailed { continue }
    }
    
    throw SolverError.guessingFailed
}

/// If we find that a particular number has to go in a particular cell, this method can be used to update the board's possbility matrix accordingly.
fileprivate func updateKnownCell(withBitfieldComplement bc: Bitfield, at index: CellIndex, in possibilityMatrix: inout PossibilityMatrix) {
    
    // Set bits associated with the possibility of this sudoku number to 0 in its row, column, and square.
    var newMatrix = possibilityMatrix
        .mapRow(containing: index) { $0 & bc }
        .mapColumn(containing: index) { $0 & bc }
        .mapSquare(containing: index) { $0 & bc }
    
    // Set a single bit for this cell, which indicates we know the corresponding number in the sudoku board
    newMatrix[index] = ~bc
    
    possibilityMatrix = newMatrix
}

/// For each cell, this function looks through the other cells in row, column, and square, and identifies if there are any numbers that can't go anywhere else but the current cell.
fileprivate func cellEliminationPass(through possibilityMatrix: inout PossibilityMatrix) throws  {
    
    // Create an matrix that represents the updates we need to make.  Non-zero cells should store bitfield complements that can be used to update the possibility matrix.
    var updateBitmasks = try possibilityMatrix.map { (cellIndex, numberPossibilities) in
        guard numberPossibilities != 0 else { throw SolverError.internalInconsistency }
        
        // Short circuit with no update if we already know a value for this cell
        guard numberPossibilities.singleBitSet == false else { return 0 }
        
        /// Helper method that implements code common to row, columns, and squares. It looks for a number that can only go in one spot.
        /// - Parameter complement: a set of cells that are in the same row, column, or square as the current cell, but _excluding_ the current cell.
        /// - Returns: If such a number exists, it returns the complement to that number's possibility bitfield, and nil otherwise.  For example, it will return 11...1101111 for the number 5.
        func findComplementPossibilities(in complement: [Bitfield]) throws -> Bitfield? {
            let complementPossibilties = complement.reduce(~Bitfield.mask, |)
            if complementPossibilties.allBitsSet {
                return nil
            } else {
                // Check there is only one 0; if there are multiple, we must throw an error because we cannot put more than one number in the same cell!
                guard complementPossibilties.singleBitUnset else { throw SolverError.eliminationInconsistency }
                return complementPossibilties
            }
        }
        
        // Check row complement
        var row = possibilityMatrix.row(containing: cellIndex)
        row[cellIndex.1] = 0 // Ignore the current cell
        if let complementPossibilities = try findComplementPossibilities(in: row) { return complementPossibilities }
        
        // Check column complement
        var col = possibilityMatrix.column(containing: cellIndex)
        col[cellIndex.0] = 0 // Ignore the current cell
        if let complementPossibilities = try findComplementPossibilities(in: col) { return complementPossibilities }
        
        // Check square complement
        var square = possibilityMatrix.square(containing: cellIndex)
        square[3*(cellIndex.0 % 3) + (cellIndex.1 % 3)] = 0 // Ignore the current cell
        if let complementPossibilities = try findComplementPossibilities(in: square) { return complementPossibilities }
        
        // No update
        return 0
    }
    
    // Loop through update matrix and perform updates
    updateBitmasks.forEach{ index, bitmask in
        guard bitmask != 0 else { /* no update */ return }
        updateKnownCell(withBitfieldComplement: bitmask, at: index, in: &possibilityMatrix)
    }
}


// MARK: - Matrix Extensions
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
    
    var hasUnknownCell: Bool {  return firstUnknownCell != nil}
    
    var hasZeroCell: Bool {
        for i in 0..<self.storage.count {
            for j in 0..<self.storage[i].count {
                if self[(i,j)] == 0 { return true }
            }
        }
        return false
    }
    
    /// Loop through known values in the sudoku and look for duplicates in rows, columns, squares.
    var representsValidSudoku: Bool {
        for i in 0..<self.storage.count {
            let idx = (i,i)
            
            let row = self.row(containing: idx).filter{ $0.singleBitSet }
            guard Set(row).count == row.count else { return false }
            
            let col = self.column(containing: idx).filter{ $0.singleBitSet }
            guard Set(col).count == col.count else { return false }
            
            let square = self.square(containing: idx).filter{ $0.singleBitSet }
            guard Set(square).count == square.count else { return false }
        }
        return true
    }
}

// MARK: - Errors
enum SolverError: Error {
    case maxIter
    case noSolutionFound
    case invalidSudoku
    case internalInconsistency
    
    case eliminationInconsistency
    case guessingFailed
}


