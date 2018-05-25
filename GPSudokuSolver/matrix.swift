//
//  Matrix.swift
//  GPSudokuSolver
//
//  Created by Gord Parke on 5/24/18.
//  Copyright © 2018 Gord Parke. All rights reserved.
//

import Foundation


struct Matrix: Equatable {
    typealias CellIndex = (Int, Int) // Row, col
    
    var storage: [[UInt16]] // Should always be 9x9
    
    // MARK: Row, column, square accessors
    func row(containing index: CellIndex) -> [UInt16] {
        return storage[index.0]
    }
    
    func column(containing index: CellIndex) -> [UInt16] {
        return storage.map{ $0[index.1] }
    }

    
    /// 3x3 submatrix, indexed in row major order
    /// NB: Assumes matrix is 9x9!
    func square(containing index: CellIndex) -> [UInt16] {
        let upperLeftIdx = (Int(index.0 / 3)*3, Int(index.1 / 3)*3)
        return storage[upperLeftIdx.0 ..< upperLeftIdx.0+3].flatMap{ $0[upperLeftIdx.1 ..< upperLeftIdx.1+3] }
    }
    
    // MARK: Transform
    func map(_ transform: (CellIndex, UInt16) throws -> (UInt16)) rethrows -> Matrix {
        return try Matrix(storage.enumerated().map{ i, row in
            try row.enumerated().map{ j, value in
                return try transform((i,j), value)
            }
        })
    }
    
    
    // MARK: Subscripting
    subscript(index: CellIndex) -> UInt16 {
        get {
            return storage[index.0][index.1]
        }
        set {
            storage[index.0][index.1] = newValue
        }
    }
    
    // MARK: Lifecycle
    init(_ storage: [[UInt16]]) {
        self.storage = storage;
    }
}
