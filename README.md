# Txt to Json parser
Repository provides a parser that converts output.txt into a structured JSON format (output.json).

## Input and Output Examples:
### Input (```output.txt```):
```plaintext
[ Asserts Samples ], 1..7 tests
-----------------------------------------------------------------------------------
not ok  1  expecting command finishes successfully (bash way), 7ms
not ok  2  expecting command finishes successfully (the same as above, bats way), 27ms
ok  3  expecting command fails (the same as above, bats way), 23ms
ok  4  expecting command prints exact value (bash way), 10ms
ok  5  expecting command prints exact value (the same as above, bats way), 27ms
ok  6  expecting command prints some message (bash way), 12ms
ok  7  expecting command prints some message (the same as above, bats way), 26ms
-----------------------------------------------------------------------------------
5 (of 7) tests passed, 2 tests failed, rated as 71.43%, spent 136ms
```
### Output (```output.json```):
```json
{
    "testName": "Asserts Samples",
    "tests": [
        {
            "name": "expecting command finishes successfully (bash way)",
            "status": false,
            "duration": "7ms"
        },
        {
            "name": "expecting command finishes successfully (the same as above, bats way)",
            "status": false,
            "duration": "27ms"
        },
        {
            "name": "expecting command fails (the same as above, bats way)",
            "status": true,
            "duration": "23ms"
        },
        {
            "name": "expecting command prints exact value (bash way)",
            "status": true,
            "duration": "10ms"
        },
        {
            "name": "expecting command prints exact value (the same as above, bats way)",
            "status": true,
            "duration": "27ms"
        },
        {
            "name": "expecting command prints some message (bash way)",
            "status": true,
            "duration": "12ms"
        },
        {
            "name": "expecting command prints some message (the same as above, bats way)",
            "status": true,
            "duration": "26ms"
        }
    ],
    "summary": {
        "success": 5,
        "failed": 2,
        "rating": 71.43,
        "duration": "136ms"
    }
}
```

## Usage
**Requirements:** 
- Bash shell environment.
- Input file (output.txt) must follow the expected format for proper parsing.
  
**Running the script:** 

```bash
./task2.sh path/to/output.txt
```
