# GPSudokuSolver

A Swift commandline application that solves Sudoku puzzles.  Sudokus can be passed in using standard input, or fetched randomly from sugoku.herokuapp.com.

## Easy Example
```
Fetching sudoku from sugoku.herokuapp.com....
Solving sudoku:

    4 | 9 7   |      
    6 |       |     9
      | 1     | 2 3  
---------------------
  1   | 4 6   |      
4 6   |   8 9 |   2 3
8 9 7 |   1 2 |     6
---------------------
5   1 |     4 |   8  
  4   | 5   7 | 3   2
9     |   2 1 |   4  

Solved sudoku in 4 ms:

2 3 4 | 9 7 8 | 5 6 1
1 5 6 | 2 4 3 | 8 7 9
7 8 9 | 1 5 6 | 2 3 4
---------------------
3 1 2 | 4 6 5 | 7 9 8
4 6 5 | 7 8 9 | 1 2 3
8 9 7 | 3 1 2 | 4 5 6
---------------------
5 2 1 | 6 3 4 | 9 8 7
6 4 8 | 5 9 7 | 3 1 2
9 7 3 | 8 2 1 | 6 4 5
```

## Hard Example
```
Solving sudoku:

3     |     7 |     5
      |     9 | 4    
      |       |     3
---------------------
2 1   |   4   | 6    
    5 |       | 3    
    7 | 3   2 |      
---------------------
5     |       |      
6     |     4 | 7 5 1
9 7   | 1     | 2 3 6

Solved sudoku in 130 ms:

3 4 2 | 6 8 7 | 1 9 5
1 8 6 | 5 3 9 | 4 2 7
7 5 9 | 4 2 1 | 8 6 3
---------------------
2 1 3 | 9 4 5 | 6 7 8
4 9 5 | 8 7 6 | 3 1 2
8 6 7 | 3 1 2 | 5 4 9
---------------------
5 2 1 | 7 6 3 | 9 8 4
6 3 8 | 2 9 4 | 7 5 1
9 7 4 | 1 5 8 | 2 3 6
```
