<# Parameter block with parameters that the script expects to receive when it is executed. 

    $rating -> Parameter for the rating of the game (string)
    $count -> Parameter for the count of something (integer)
    $themes -> Parameter for an array of themes (array of strings) #>
param
(
    [string]$rating,
    [int]$count,
    [string[]]$themes
)

function GetChessPuzzles([int]$rating, [int]$count, [string[]]$themes) {
    <# Url for chess API endpoint #>
    $endpoint = 'https://chess-puzzles.p.rapidapi.com/'

    <# Construct themes parameter in the query string.
        -join -> Operator to concatenate the elements of the $themes array into a single string.
        Parameter "," -> It will use comma to join each element #>
    $themesParam = '["' + ($themes -join '","') + '"]'

	<# Define query string. Combining parameters in one string #>
    $queryString = "?rating=$rating&count=$count&themes=$themesParam&themesType=ALL"

    <# Combine endpoint and query string #>
    $uri = $endpoint + $queryString

    <# Define headers.
        @{} -> PowerShell hash table. This are data structures that store key-value pairs. #>
    $headers = @{
        'X-RapidAPI-Key' = 'YOUR API KEY'
        'X-RapidAPI-Host' = 'chess-puzzles.p.rapidapi.com'
    }

    <# Send the GET request 
        Invoke-RestMethod -> This is a cmdlet used to send HTTP and HTTPS requests
        Parameter -Uri -> Endpoint where we send request 
        Parameter -Method -> Type of call #>
    $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers

    # $jsonContent = Get-Content -Path "puzzles.json" -Raw
    # $response = $jsonContent | ConvertFrom-Json

    # Output the response
    return $response
}

# Example usage:
GetChessPuzzles -rating $rating -count $count -themes $themes
#$puzzles | ConvertTo-Json | Out-File -FilePath "puzzles.json"