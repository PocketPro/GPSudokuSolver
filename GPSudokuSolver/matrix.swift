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
    
    func forEach(_ operation: (CellIndex, UInt16) throws -> Void) rethrows {
        for i in 0 ..< storage.count {
            let row = storage[i]
            for j in 0 ..< row.count {
                let cellIndex = (i,j)
                try operation(cellIndex, storage[i][j])
            }
        }
    }
    
    func mapRow(containing index: CellIndex, transform: (UInt16) throws -> (UInt16)) rethrows -> Matrix {
        var newStorage = storage
        newStorage[index.0] = try storage[index.0].map(transform)
        return Matrix(newStorage)
    }
    
    
    func mapColumn(containing index: CellIndex, transform: (UInt16) throws -> (UInt16)) rethrows -> Matrix {
        let j = index.1
        var newStorage = storage
        for i in 0..<storage.count {
            newStorage[i][j] = try transform(storage[i][j])
        }
        return Matrix(newStorage)
    }
    
    // NB: Assumes matrix is 3x3!
    func mapSquare(containing index: CellIndex, transform: (UInt16) throws -> (UInt16)) rethrows -> Matrix {
        var newStorage = storage
        let upperLeftIdx = (Int(index.0 / 3)*3, Int(index.1 / 3)*3)
        for i in upperLeftIdx.0 ..< (upperLeftIdx.0 + 3) {
            for j in upperLeftIdx.1 ..< (upperLeftIdx.1 + 3) {
                newStorage[i][j] = try transform(storage[i][j])
            }
        }
        return Matrix(newStorage)
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
