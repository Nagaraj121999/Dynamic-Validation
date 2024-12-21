# Input Validation Solution Using Dynamic Programming in ABAP

## Project Description
This solution addresses the challenge of validating internal or work area data before storing it into a database table. Not all fields are free input, and the traditional method of validation involves fetching check values from the database and comparing them row by row for each column. While simple, this approach can be very time-consuming for consultants. What if we could automate this process by simply specifying, "compare this field with this table and tell me if it contains an invalid value"? This is the goal of this solution.

## Features
1. Dynamically validate any internal table or work area with minimal information.
2. It will not validate internal tables and work areas. It validates deep structures (e.g., internal table inside an internal table, work area inside an internal table, internal table inside a work area, work area inside a work area, etc.).
3. Do the conversion exit and give unconverted value for storing
## Installation Instructions
1. Create the class in SE24.
2. Call it with the necessary format. That's it.

## Technologies Used
- ABAP

## Contribution
- The solution does not support validation when multiple primary keys are involved. For example, house bank and account ID cannot be validated together; they will be validated independently.
- It does not specify which records contain incorrect values. The results are returned in a static manner.
