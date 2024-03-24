<# Instance of the PSCustomObject (class type from .NET) that will track game state and player's progress.
Object properties:  
  puzzlesDone -> Array created using syntax @(). This array will track if user successfully completed puzzles
  numberOfTries -> Propery of .NET type System.Int32
  whiteToPlay -> Boolean property that tells user what color piece to move
  currentPuzzleNumber -> Another integer. Keeps track of current puzzle number.
  board -> Set to $Null value but it will be initialized later in code
  puzzle -> PowerShell object that represents current puzzle.
#>
$gameState = [PSCustomObject]@{
  puzzlesDone = @("/", "/", "/")
  numberOfTries = 5
  whiteToPlay = $true
  currentPuzzleNumber = 0
  board = $null
  puzzle = $null
}

function Chess{
  <# Set up empty chess board #>
  $gameState.board = InitializeBoard

  <# Ask player to chose difficulty, rating and theme of puzzles #>
  $selectedDifficulty = SelectDifficulty
  $gameState.numberOfTries = $selectedDifficulty
  $rating = SelectRating
  $themes = SelectCategory

  <# Call API and fetch puzzles #>
  $puzzleApi = FetchPuzzles -rating $rating -themes $themes

  <# Do while application is running. While loop will run until player reaches last puzzle. (puzzle number 3) #>
  while ($gameState.currentPuzzleNumber -le 2) {
    <# Before each puzzle #>
    $gameState.puzzle = $puzzleApi.puzzles[$gameState.currentPuzzleNumber]
    DoBeforeEachPuzzle
    $currentMove = 1
    
    <# While solving puzzle #>
    while ($gameState.numberOfTries -gt 0){
      
      <# User enters move #>
      $move = UserEntersMove

      <# Check if move is corect #>
      if ($move -eq $gameState.puzzle.moves[$currentMove]) {
        <# If move is correct... #>
        DoIfMoveIsCorrect
        $currentMove += 2
        <# Check if puzzle is solved #>
        if ($currentMove -ge $gameState.puzzle.moves.Count) {
          PuzzleSolved
          break
        }
        <# Move piece for oponent #>
        MovePiece -move $gameState.puzzle.moves[$currentMove - 1]

      } else {
        <#If move is incorrect... #>
        DoIfMoveIsIncorrect
      }
    }
    <# If player made more than 3 mistakes, mark current puzzle as incorrect.#>
    if($gameState.numberOfTries -le 0){
      $gameState.puzzlesDone[$gameState.currentPuzzleNumber] = 'i'
    }
    $gameState.currentPuzzleNumber += 1
  }

  <# Showing results and closing application #>
  DisplayGoodBye
}




function DisplayGoodBye{
  <# Set the board to an empty state.
    Show the player how many of 3 puzzles they have solved correctly.
    Write a goodbye message. 
  #>
  $gameState.board = InitializeBoard
  Visualize
  $successfullySolved = ($gameState.puzzlesDone -eq 'c').Count
  Write-Host "You successffully solved $successfullySolved/3 puzzles."
  Write-Host "Goodbye"
}

function InitializeBoard {
  <# The data type of $emptyBoard is an array of characters.
      New-Object -> Creates a new object
      Parameter 'char[]' -> Specifies the type of object to create, which is an array of characters
      Parameter 64 -> Specifies the length of the array to be created

    After object creation, there is simple for loop that sets space character " " for every element of array
      -lt -> Operator that stands for "less than"
  #>
  $emptyBoard = New-Object 'char[]' 64
  for ($i = 0; $i -lt 64; $i++) {
      $emptyBoard[$i] = " " 
  }

  return $emptyBoard
}

function FetchPuzzles([int]$rating, [string[]]$themes){
  <# Simple method that calls another .ps1 script and passes it three arguments: rating, count, and themes.
    The Parameter -PipelineVariable returns the fetched puzzle as the return value to this script. 
  #>
  $count = 3
  Write-Host "Fetching puzzles..."
  $apiResponse = Invoke-Expression -Command "& ./puzzle.ps1 $rating $count $themes" -PipelineVariable returnValue
  return $apiResponse
}

function ChessNotationToIndex([string]$notation) {
    # Extract file (column) and rank (row) from the notation
    $fileIndex = [int][char]($notation[0]) - [int][char]'a'
    $rankIndex = [int][char]($notation[1]) - [int][char]'0' - 1

    # Calculate the 1D index using row-major order
    return $rankIndex * 8 + $fileIndex
}

function SetChessBoard([string]$fen) {

  <# Reset the chessboard. Iterate through each element of the array and set it to a space ' '. Do this to remove pieces from the previous puzzle. #>
  for ($i = 0; $i -lt 64; $i++) {
      $gameState.board[$i] = " " 
  }

  <# Split the FEN string to extract board state and other information #>
  $fenParts = $fen -split ' '

  <# Extract the board state from the FEN #>
  $position = $fenParts[0]

  <# Initialize row and column indices #>
  $rowIndex = 7
  $colIndex = 0

  <# Parse each character of the board state #>
  foreach ($char in $position.ToCharArray()) {
      <# Check if the character represents a piece or empty square #>
      if ($char -match '[1-8]') {
          <# If it's a number, skip that many empty squares #>
          $colIndex += [int][char]$char - [int][char]'0'
      }
      elseif ($char -match '[a-zA-Z]') {
          <# If it's a piece, place it on the board #>
          $gameState.board[$rowIndex * 8 + $colIndex] = $char
          $colIndex++
      }
      elseif ($char -eq '/') {
          <# If it's a slash, move to the next row #>
          $rowIndex--
          $colIndex = 0
      }
  }
}

function SetTurn ([string]$fen){
  <# Simple method that takes a FEN (Forsyth–Edwards Notation), splits it, and reads the part where 'b' represents black to play, or 'w' represents white to play. #>
  $fenParts = $fen -split ' '

  <# Return boolean represents white or black to play. #>
  return $fenParts[1] -eq 'b'
}

function SelectCategory {
  Visualize

  <# Array that contains some of the puzzle types.#>
  $categories = @(
      "Endgame",
      "Middlegame",
      "Opening",
      "Mate",
      "Zugzwang"
  )

  <# Display the menu.
      Display all available puzzle categories from the array with simple for loop.
  #>
  Write-Host "Select a category (enter the corresponding number):"
  Write-Host
  for ($i = 0; $i -lt $categories.Count; $i++) {
      Write-Host "$($i + 1).) $($categories[$i])"
  }

  Write-Host
  $selection = Read-Host "Enter your choice (1-5)"

  <# Validate the input. Waiting in while loop for player to enter valid number in interval 1 - 5. #>
  while ($selection -notin 1..5) {
      Write-Host "Invalid selection. Please enter a number between 1 and 5."
      Write-Host
      $selection = Read-Host "Enter your choice (1-5)"
  }
  <# Converting selected category into lowercase string. #>
  $selectedCategory = $categories[$selection - 1].ToLower()

  return @($selectedCategory)
}

function SelectDifficulty {
  Visualize

  <# Array that contains different difficulty levels players can choose from. #>
  $difficulties = @(
      "Easy   (5 mistakes allowed) ❤️❤️❤️❤️❤️",
      "Normal (3 mistakes allowed) ❤️❤️❤️",
      "Hard   (1 mistake allowed)  ❤️"
  )

  <#  Display the menu. 
      Difficulty levels are shown with the help of a for loop.
      Write-Host without parameters will write empty line.
  #>
  Write-Host "Select a difficulty (enter the corresponding number):"
  Write-Host
  for ($i = 0; $i -lt $difficulties.Count; $i++) {
      Write-Host "$($i + 1).) $($difficulties[$i])"
  }

  Write-Host
  $selection = Read-Host "Enter your choice (1-3)"

  <#  Validate the input.
      Read-Host will wait for the player's input.
      The while loop will run until the player enters valid input.
      In this case, valid input is marked with '1..3', indicating that valid input is 1, 2, or 3.
      -notin -> This represents logical NOT. 
  #>
  while ($selection -notin 1..3) {
      Write-Host "Invalid selection. Please enter a number between 1 and 3."
      Write-Host
      $selection = Read-Host "Enter your choice (1-3)"
  }

  <# Simple if-else statement that returns the value of tries available to the player depending on the input provided. #>
  if($selection -eq 1){
    return 5
  }elseif ($selection -eq 3) {
    return 1
  }else{
    return 3
  }
}

function SelectRating{
  Visualize
  <# Display the menu #>
  Write-Host "Enter rating for your puzzles (number):"
  Write-Host
  $enteredRating = Read-Host "Enter rating (700 - 3000)"

  <# Validate the input.
    Again waiting for player to input valid number between 700 and 3000.
    While loop will continue untill valid number is entered.
  #>
  while ($enteredRating -notin 700..3000) {
      Write-Host "Invalid rating. Please enter a number between 700 and 3000."
      Write-Host
      $enteredRating = Read-Host "Enter rating (700 - 3000)"
  }

  return $enteredRating
}

function GetPieceIcon {
  param (
      [char]$piece
  )

  <# Switch case that returns ASCII symbol for a chess piece.
    Characters are converted to their ASCII integer value for processing.
  #>

  switch ([int][char]$piece) {
        80  { return '♟' }  # P
        82  { return '♜' }  # R
        78  { return '♞' }  # N
        66  { return '♝' }  # B
        81  { return '♛' }  # Q
        75  { return '♚' }  # K
        112 { return '♙' }  # p
        114 { return '♖' }  # r
        110 { return '♘' }  # n
        98  { return '♗' }  # b
        113 { return '♕' }  # q
        107 { return '♔' }  # k
      default { return $piece }
  }
}

function ReplacePieceLettersWithIcons {
  <# Iterate through an array representing the chessboard and replace characters with ASCII chess piece symbols. #>
  for ($i = 0; $i -lt 64; $i++) {
    $gameState.board[$i] = GetPieceIcon -piece $gameState.board[$i]
  }
}

function DisplayChessBoard {
  <# Method for displaying the chessboard. Special characters are used to enhance appearance.
   -NoNewline argument in Write-Host disables automatic new line insertion.
   -BackgroundColor DarkGray sets the background color for black board squares.
   The board is drawn using nested loops: one for ranks and another for files. 
  #>
  ReplacePieceLettersWithIcons
  Write-Host
  Write-Host "      ┌────────────────┐"

  for ($rank = 7; $rank -ge 0; $rank--) {
      Write-Host ("    " + [char]([string]($rank + 1)[0]) + " │") -NoNewline
      for ($file = 0; $file -lt 8; $file++) {
          $index = $rank * 8 + $file
          if (($rank + $file) % 2 -eq 0) {
                Write-Host "$($gameState.board[$index]) " -BackgroundColor DarkGray -NoNewline
            } else {
                Write-Host -NoNewline "$($gameState.board[$index]) " 
            }
          
      }
      Write-Host "│" -NoNewline
      Write-Host
  }

  Write-Host "      └────────────────┘"
  Write-Host "        a b c d e f g h "
  Write-Host 
  Write-Host "============================="
}

function Visualize {
  <#  Clear-Host -> Clears the contents of the host display
      DisplayTitle -> Function that renders and displays header of terminal
      DisplayChessBoard -> Function that displays board
  #>
  Clear-Host
  DisplayTitle
  DisplayChessBoard
}

function UserEntersMove {
  Visualize
  <# Give user information if he playswith white or black pieces. #>
  if($gameState.whiteToPlay){
    Write-Host "White to move."
  }else {
    Write-Host "Black to move."
  }

  <# Prompt the user to enter a move #>
  $move = Read-Host "Enter move (e.g., e2e4)"

  <# Validate the input format. 
     This regex: '^[a-h][1-8][a-h][1-8]$' requires the user to enter the move in the format fromTile toTile, for example ('e2e4').
     The while loop will run until the player enters the correct format of input. 
    #>
  while ($move -notmatch '^[a-h][1-8][a-h][1-8]$') {
      Write-Host "Invalid move format. Please enter your move in valid format."
      $move = Read-Host "Enter move (e.g., e2e4)"
  }

  <# Return the validated move #>
  return $move
}

function MovePiece([string]$move) {
  <# Separate move string (for example 'e2e4') into two substrings representing tiles ('e2' and 'e4'). #>
  $fromTile = $move.Substring(0, 2)
  $toTile = $move.Substring(2, 2)

  <# Convert chess notation to indices #>
  $fromIndex = ChessNotationToIndex $fromTile
  $toIndex = ChessNotationToIndex $toTile

  <# Perform the move #>
  $gameState.board[$toIndex] = $gameState.board[$fromIndex]
  $gameState.board[$fromIndex] = ' '

  <# Call Visualize method to show changes on display.#>
  Visualize
}

function DisplayTitle {
  $heartsString = ""
  $puzzlesDoneString = ""

  #Add black hearts to heartsString.
  $numberOfBlackHearts = 5 - $gameState.numberOfTries
  for ($i = 0; $i -lt $numberOfBlackHearts; $i++) {
    $heartsString = $heartsString + "🖤";
  }

  # Add red hearts to string. One heart is added for each number of tries the player has left.
  for ($i = 0; $i -lt $gameState.numberOfTries; $i++) {
    $heartsString = $heartsString + "❤️ ";
  }

  <# Simple switch-case that will add emoji symbols to represent the status of puzzles done.
      If 'i' (incomplete), adds a cross mark "❌" to the string.
      If 'c' (completed), adds a check mark "✅" to the string.
      For any other case, adds a blue square "🟦" to the string. 
  #>
  switch ($gameState.puzzlesDone) {
    'i' { $puzzlesDoneString = $puzzlesDoneString + "❌" }
    'c' { $puzzlesDoneString = $puzzlesDoneString + "✅"}
    Default { $puzzlesDoneString = $puzzlesDoneString + "🟦" }
  }

  <# Display the current state of puzzles done and hearts remaining #>
  Write-Host "$puzzlesDoneString /==============\$heartsString"
}

function DoBeforeEachPuzzle {
  <# Reset the number of tries player has left (heart emojis).
      Set chessboard position to puzzle starting position using FEN.
      Determine whose turn it is to play (white or black).
      Make the first move into the puzzle. 
  #>
  $gameState.numberOfTries = $selectedDifficulty
  SetChessBoard -fen $gameState.puzzle.fen
  $gameState.whiteToPlay = SetTurn -fen $gameState.puzzle.fen
  MovePiece -move $gameState.puzzle.moves[0]
}

function DoIfMoveIsCorrect{
  <# Make a move for the opponent. 
      Provide player feedback that the move played is correct. 
      Start-Sleep will pause the game, freezing the terminal for 1.5 seconds, giving the feeling that the opponent is an actual person making a move.
  #>
  MovePiece -move $move
  Write-Host "Correct move!" -ForegroundColor Green
  if($gameState.whiteToPlay){
    Write-Host "Black is now playing..."
  }else{
    Write-Host "White is now playing..."
  }
  Start-Sleep -Seconds 1.5
}

function DoIfMoveIsIncorrect{
  <# Provide player feedback that a wrong move was made. Sleep the terminal for 1.5 seconds to ensure the player can read it. #>
  Write-Host "Incorrect move." -ForegroundColor Red
  Start-Sleep -Seconds 1.5
  <# Reduce the number of tries the player has left by 1. #>
  $gameState.numberOfTries -= 1
}

function PuzzleSolved{
  <# Give player feedback that puzzle is solved. Also freeze terminal for 1.5 second so player can read it.#>
  Write-Host "✅ Congratulations! You solved the puzzle " ($gameState.currentPuzzleNumber+1) "successfully!" -ForegroundColor Green
  $gameState.puzzlesDone[$gameState.currentPuzzleNumber] = 'c'
  Start-Sleep -Seconds 1.5
}

Chess