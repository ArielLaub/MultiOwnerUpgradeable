# Multi-Owner Smart Contract System

## Overview

This project implements a multi-owner smart contract system with upgradeable functionality using Foundry. It's designed to provide a secure and flexible way to manage ownership and permissions in decentralized applications.

## Key Features

- Multi-owner management
- Upgradeable contracts
- Whitelist functionality
- Approval-based execution
- Flexible ownership transfer

## Main Components

### MultiOwnableUpgradeable

An abstract contract that provides multi-owner functionality with upgradeability support. It includes owner-only access control, approval-based execution of functions, and integration with OwnersGroup for managing owners.

### OwnersGroup

A contract for managing a group of owners with multi-signature functionality. Features include adding and removing owners, whitelisting contracts, an approval mechanism for actions, and configurable minimum required approvers.

## Installation

1. Ensure you have Foundry installed. If not, follow the [official Foundry installation guide](https://book.getfoundry.sh/getting-started/installation).
2. Clone this repository:
   ```
   git clone <repository-url>
   cd <repository-name>
   ```
3. Install dependencies:
   ```
   forge install
   ```

## Usage

To use this system in your project:

1. Deploy the `OwnersGroup` contract with initial owners and required approvers.
2. Implement your custom contract inheriting from `MultiOwnableUpgradeable`.
3. Initialize your contract with the deployed `OwnersGroup` address.

## Testing

Run the test suite using Forge:
