# Decentralized Micro-Investment Platform

A smart contract built on the Stacks blockchain that enables users to create investment projects and allows others to make micro-investments with automated returns distribution.

## Overview

This platform facilitates decentralized micro-investments where project creators can raise funds for their ventures and investors can participate with small amounts. The contract handles fund collection, automatic refunds for failed projects, returns distribution, and maintains user reputation scores.

## Features

- **Project Creation**: Users can create investment projects with customizable parameters
- **Micro-Investments**: Support for small investment amounts with minimum thresholds
- **Automated Refunds**: Automatic refund system for projects that don't meet funding goals
- **Returns Distribution**: Built-in mechanism for distributing returns to investors
- **Reputation System**: Track user activity and build reputation scores
- **Platform Fees**: Configurable fee structure (currently 2.5%)
- **Emergency Controls**: Admin functions for platform management

## Constants

- `PLATFORM-FEE`: 250 basis points (2.5%)
- Various error codes for different failure scenarios
- Contract owner permissions for admin functions

## Core Data Structures

### Users
```
{
  total-invested: uint,
  total-projects: uint,
  reputation-score: uint,
  is-verified: bool
}
```

### Projects
```
{
  creator: principal,
  title: string-ascii 100,
  description: string-ascii 500,
  funding-goal: uint,
  current-funding: uint,
  deadline: uint,
  is-active: bool,
  is-funded: bool,
  returns-distributed: bool,
  min-investment: uint,
  expected-return-rate: uint,
  total-investors: uint
}
```

### Investments
```
{
  amount: uint,
  timestamp: uint,
  returns-claimed: bool
}
```

## Public Functions

### User Management

#### `register-user()`
Register or update user profile and increase reputation score by 10 points.

### Project Management

#### `create-project(title, description, funding-goal, deadline, min-investment, expected-return-rate)`
Create a new investment project with specified parameters.

**Parameters:**
- `title`: Project title (max 100 characters)
- `description`: Project description (max 500 characters)
- `funding-goal`: Target funding amount in microSTX
- `deadline`: Block height deadline for funding
- `min-investment`: Minimum investment amount
- `expected-return-rate`: Expected return rate in basis points (max 10000 = 100%)

**Requirements:**
- Funding goal must be greater than 0
- Deadline must be in the future
- Minimum investment must be greater than 0
- Return rate cannot exceed 100%

#### `close-project(project-id)`
Close a funded project and withdraw funds (creator only).

**Requirements:**
- Must be called by project creator
- Project must be active and funded

### Investment Functions

#### `invest-in-project(project-id, amount)`
Invest STX tokens in a specific project.

**Requirements:**
- Project must be active
- Deadline not passed
- Amount must meet minimum investment requirement
- Amount must be greater than 0

**Process:**
1. Deducts platform fee (2.5%)
2. Records investment
3. Updates project funding status
4. Adds investor to project if first investment

#### `refund-investment(project-id)`
Claim refund for failed project (deadline passed without reaching goal).

**Requirements:**
- Deadline must have passed
- Project must not be funded
- Investment must not already be refunded

### Returns Management

#### `distribute-returns(project-id)`
Mark project returns as ready for distribution (creator only).

**Requirements:**
- Must be called by project creator
- Project must be closed
- Returns not already distributed

#### `claim-returns(project-id)`
Claim investment returns for a specific project.

**Requirements:**
- Returns must be marked as distributed
- Returns not already claimed

### Admin Functions

#### `withdraw-platform-fees(amount)`
Withdraw accumulated platform fees (contract owner only).

#### `emergency-pause-project(project-id)`
Emergency pause a project (contract owner only).

## Read-Only Functions

### User Information
- `get-user(user)`: Get user profile
- `get-platform-treasury()`: Get platform fee balance

### Project Information
- `get-project(project-id)`: Get project details
- `get-next-project-id()`: Get next available project ID
- `is-project-funded(project-id)`: Check if project reached funding goal

### Investment Information
- `get-investment(investor, project-id)`: Get investment details
- `calculate-returns(project-id, investment-amount)`: Calculate potential returns
- `get-project-investor(project-id, investor-index)`: Get investor at specific index
- `get-investor-count(project-id)`: Get total investors for project

## Error Codes

- `ERR-NOT-AUTHORIZED (100)`: Unauthorized access
- `ERR-ALREADY-EXISTS (101)`: Resource already exists
- `ERR-NOT-FOUND (102)`: Resource not found
- `ERR-INSUFFICIENT-FUNDS (103)`: Insufficient funds
- `ERR-PROJECT-CLOSED (104)`: Project is closed
- `ERR-PROJECT-NOT-FUNDED (105)`: Project not funded
- `ERR-ALREADY-WITHDRAWN (106)`: Already withdrawn
- `ERR-INVALID-AMOUNT (107)`: Invalid amount
- `ERR-DEADLINE-PASSED (108)`: Deadline has passed
- `ERR-DEADLINE-NOT-REACHED (109)`: Deadline not reached
- `ERR-ZERO-AMOUNT (110)`: Zero amount not allowed

## Usage Examples

### Creating a Project
```clarity
(contract-call? .micro-investment create-project 
  "Solar Panel Installation"
  "Funding needed for community solar panel installation project"
  u1000000  ;; 1000 STX funding goal
  u2000     ;; Deadline at block 2000
  u10000    ;; Minimum 10 STX investment
  u1500     ;; 15% expected return
)
```

### Investing in a Project
```clarity
(contract-call? .micro-investment invest-in-project u1 u50000) ;; Invest 50 STX in project 1
```

### Claiming Refund
```clarity
(contract-call? .micro-investment refund-investment u1)
```

## Security Considerations

- All STX transfers use the `try!` macro for safe execution
- Access controls prevent unauthorized actions
- Automatic refund mechanism protects investors
- Platform fees are held in contract treasury
- Emergency pause functionality for admin intervention

## Deployment Requirements

- Stacks blockchain environment
- Clarity smart contract support
- STX token support for payments