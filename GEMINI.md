# Project Documentation: Marketplace Double

This document provides an overview of the Marketplace Double project, its purpose, technology stack, and development guidelines.

## Project Overview

The Marketplace Double project is a Stacks blockchain application focused on facilitating the trading of fungible tokens (FTs). It allows users to list FTs for sale, specifying details such as the token contract, desired price, payment method (STX or another FT), and listing expiry. The system includes robust features for managing listings, ensuring secure transactions, and maintaining contract integrity.

**Key Features:**

*   **FT Listings:** Users can list FTs with specified amounts, prices, and expiry blocks.
*   **Payment Flexibility:** Supports STX and whitelisted SIP010 FTs as payment.
*   **Listing Management:** Functionality to update, cancel, and fulfill listings.
*   **Whitelisting:** Contract owner can whitelist FT and payment contracts.
*   **Emergency Stop:** An owner-controlled mechanism to pause contract operations.
*   **Fee System:** Configurable transaction fees based on basis points (BPS).
*   **Milestone Payments:** Supports phased payments for listings, potentially for larger transactions or escrow-like arrangements.
*   **Protocol Contract Management:** Ability to update associated protocol contracts.

**Technology Stack:**

*   **Smart Contracts:** Clarity (v3, epoch 3.1)
*   **Blockchain:** Stacks
*   **Development Environment:** Clarinet
*   **Testing Framework:** Vitest, TypeScript
*   **Core Libraries:** `@stacks/clarinet-sdk`, `@stacks/transactions`

## Building and Running

This project primarily involves smart contract development and testing.

### Smart Contract Development & Simulation

*   **Clarinet Configuration:** The `Clarinet.toml` file defines the project's contracts, their Clarity versions, epochs, and dependencies.
*   **Simulation:** The Clarinet SDK and `vitest-environment-clarinet` are used to simulate the Stacks network (Simnet) for testing purposes.

### Testing

The project uses Vitest for running automated tests written in TypeScript.

*   **Run All Tests:**
    ```bash
    npm test
    ```
    This command executes `vitest run` to perform a full test suite run.

*   **Generate Detailed Reports:**
    ```bash
    npm run test:report
    ```
    This command runs tests with coverage and cost reporting enabled (`vitest run -- --coverage --costs`).

*   **Watch Mode:**
    ```bash
    npm run test:watch
    ```
    This command uses `chokidar-cli` to monitor changes in test files (`tests/**/*.ts`) and contract files (`contracts/**/*.clar`), automatically re-running tests upon modification.

## Development Conventions

### Smart Contracts (Clarity)

*   **Modularity:** Contracts are organized into multiple files (e.g., `marketplace-double.clar`, `marketplace-admin.clar`), utilizing Clarity traits and imports for modularity.
*   **Error Handling:** Explicit error codes are defined as constants (`define-constant`) and used throughout the contract for clear error reporting.
*   **State Management:** Stacks Maps (`define-map`) are extensively used to manage contract state, such as listings, whitelisted contracts, and user investment pools.
*   **Clarity Version & Epoch:** All contracts are configured for Clarity version 3 and epoch 3.1.
*   **Readability:** Code includes comments explaining complex logic, variable purposes, and error conditions.

### Testing (TypeScript & Vitest)

*   **Test Structure:** Tests are written in TypeScript files (e.g., `marketplace-double.test.ts`) within the `tests/` directory.
*   **Clarinet Integration:** Vitest is configured via `vitest.config.js` to use `vitest-environment-clarinet`, providing global access to `simnet` and Clarity SDK helpers.
*   **Assertions:** Custom Vitest matchers (e.g., `.toBeUint()`) are used for asserting Clarity values.
*   **Test Coverage:** Tests cover various aspects including ownership, whitelisting, FT listings, fulfillment, fees, emergency stop, and milestone-based payments.

### Project Structure

*   **`contracts/`**: Contains the Clarity smart contract implementations.
*   **`tests/`**: Contains the TypeScript test files.
*   **`deployments/`**: Configuration files for deploying contracts to different networks.
*   **`chainhooks/`**: Predicate configurations, likely for off-chain logic interacting with contracts.
*   **`settings/`**: Environment-specific configurations.
*   **`package.json` / `package-lock.json`**: Node.js project dependencies and scripts.
*   **`Clarinet.toml`**: Clarinet project configuration.
*   **`tsconfig.json`**: TypeScript compiler configuration.
*   **`vitest.config.js`**: Vitest test runner configuration.
*   **`README.md`**: Project summary and test execution reports.
