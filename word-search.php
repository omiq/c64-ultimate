<?php
// WORD-SEARCH.PHP

// List of retro computing words (keep them reasonably short for 10x10)
$wordList = [
    'commodore', 'amiga', 'vic20', 'c64', 'cbm', 'pet',
    'basic', 'sprite', 'kernel', 'dos', 'irq', 'sid',
    'joystick', 'retro', 'floppy', 'tape', 'asm', 'byte',
    'nmos', 'mos', 'vicii', 'cia', 'ram', 'rom',
    'datasette', 'joystick', 'scroll', 'charset', 'poke', 'peek'
];

// Make everything uppercase for the grid
$wordList = array_map('strtoupper', $wordList);

// Pick 6 unique random words
shuffle($wordList);
$selectedWords = array_slice($wordList, 0, 6);

// Grid size
$rows = 10;
$cols = 10;

// Initialize empty grid
$grid = [];
for ($r = 0; $r < $rows; $r++) {
    $grid[$r] = array_fill(0, $cols, null);
}

// Directions: (dr, dc)
$directions = [
    [-1,  0], // up
    [ 1,  0], // down
    [ 0, -1], // left
    [ 0,  1], // right
    [-1, -1], // up-left
    [-1,  1], // up-right
    [ 1, -1], // down-left
    [ 1,  1], // down-right
];

// Try to place a single word in the grid
function placeWord(&$grid, $rows, $cols, $word, $directions, $maxTries = 200) {
    $len = strlen($word);
    for ($attempt = 0; $attempt < $maxTries; $attempt++) {
        // Random start
        $row = rand(0, $rows - 1);
        $col = rand(0, $cols - 1);
        // Random direction
        $dir = $directions[array_rand($directions)];
        $dr = $dir[0];
        $dc = $dir[1];

        // Compute end position
        $endRow = $row + $dr * ($len - 1);
        $endCol = $col + $dc * ($len - 1);

        // Check bounds
        if ($endRow < 0 || $endRow >= $rows || $endCol < 0 || $endCol >= $cols) {
            continue;
        }

        // Check each cell for compatibility
        $ok = true;
        for ($i = 0; $i < $len; $i++) {
            $rr = $row + $dr * $i;
            $cc = $col + $dc * $i;
            $cell = $grid[$rr][$cc];
            $ch   = $word[$i];

            if ($cell !== null && $cell !== $ch) {
                $ok = false;
                break;
            }
        }

        if (!$ok) {
            continue;
        }

        // Place the word
        for ($i = 0; $i < $len; $i++) {
            $rr = $row + $dr * $i;
            $cc = $col + $dc * $i;
            $grid[$rr][$cc] = $word[$i];
        }

        return true;
    }

    return false; // couldn't place word
}

// Place all selected words
foreach ($selectedWords as $word) {
    placeWord($grid, $rows, $cols, $word, $directions);
}

// Fill remaining empty cells with random letters
for ($r = 0; $r < $rows; $r++) {
    for ($c = 0; $c < $cols; $c++) {
        if ($grid[$r][$c] === null) {
            $grid[$r][$c] = chr(rand(ord('A'), ord('Z')));
        }
    }
}

?>

<html>
  <body>
  <h1>COMPUTE! WORD SEARCH</h1>
<br>
<pre>
<?php

// Print grid line by line, CRLF-terminated
for ($r = 0; $r < $rows; $r++) {
    $line = implode('', $grid[$r]);
    echo " " . $line . "\r\n";
    @ob_flush();
    flush();
}
echo "\r\n</pre>";
echo "\r\n<h2>WORDS:</h2><ol>\r\n";

foreach ($selectedWords as $w) {
    echo "<li>" .$w . "</li>\r\n";
}
echo "</ol>\r\n";
echo "</body></html>\r\n";
