// generator for the skyscrapers game

let solutions = [];

function createGrids() {
  let grid = Array(4)
    .fill()
    .map(() => Array(4).fill(0));
  solveGrid(grid, 0, 0);
  return solutions;
}

function cloneGrid(grid) {
  return grid.map((row) => [...row]);
}

function isValid(grid, row, col, num) {
  for (let x = 0; x < 4; x++) {
    if (grid[row][x] === num || grid[x][col] === num) {
      return false;
    }
  }
  return true;
}

function solveGrid(grid, row, col) {
  if (col === 4) {
    if (row === 3) {
      solutions.push(cloneGrid(grid));
      return;
    }
    row++;
    col = 0;
  }

  for (let num = 1; num <= 4; num++) {
    if (isValid(grid, row, col, num)) {
      grid[row][col] = num;
      solveGrid(grid, row, col + 1);
      grid[row][col] = 0;
    }
  }
}

// console.log(createGrid());

function computeVisibility(data) {
  let currentHeight = 0;
  let visibleCount = 0;
  for (let i = 0; i < 4; i++) {
    if (data[i] > currentHeight) {
      currentHeight = data[i];
      visibleCount++;
    }
  }
  return visibleCount;
}

function computeVisibilityTop(grid, index) {
  let columnData = Array.from({ length: 4 }, (_, i) => grid[i][index]);
  return computeVisibility(columnData);
}

function computeVisibilityBottom(grid, index) {
  let columnData = Array.from({ length: 4 }, (_, i) => grid[3 - i][index]);
  return computeVisibility(columnData);
}

function computeVisibilityLeft(grid, index) {
  return computeVisibility(grid[index]);
}

function computeVisibilityRight(grid, index) {
  let rowData = Array.from({ length: 4 }, (_, i) => grid[index][3 - i]);
  return computeVisibility(rowData);
}

let grids = createGrids();

// console.log('Visibility from Top:', Array.from({length: 4}, (_, i) => computeVisibilityTop(grid, i)));
// console.log('Visibility from Bottom:', Array.from({length: 4}, (_, i) => computeVisibilityBottom(grid, i)));
// console.log('Visibility from Left:', Array.from({length: 4}, (_, i) => computeVisibilityLeft(grid, i)));
// console.log('Visibility from Right:', Array.from({length: 4}, (_, i) => computeVisibilityRight(grid, i)));

// output to a object
const gridsOutputs = grids.map((grid) => {
  return {
    // grid: grid,
    top: Array.from({ length: 4 }, (_, i) => computeVisibilityTop(grid, i)),
    bottom: Array.from({ length: 4 }, (_, i) =>
      computeVisibilityBottom(grid, i)
    ),
    left: Array.from({ length: 4 }, (_, i) => computeVisibilityLeft(grid, i)),
    right: Array.from({ length: 4 }, (_, i) => computeVisibilityRight(grid, i)),
  };
});

// write to a file
const fs = require("fs");

fs.writeFile("grids.json", JSON.stringify(gridsOutputs), (err) => {
  if (err) {
    console.log("Error writing file", err);
  } else {
    console.log("Successfully wrote file");
  }
});
