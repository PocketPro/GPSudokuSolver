# GPSudokuSolver

A Swift commandline application that solves Sudoku puzzles.  Sudokus can be passed in using standard input, or fetched randomly from sugoku.herokuapp.com.

## Example
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
