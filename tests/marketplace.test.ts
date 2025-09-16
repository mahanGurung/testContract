import { describe, expect, it, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";


const accounts = simnet.getAccounts();
const deployer = simnet.deployer;
const wallet1 = accounts.get("wallet_1")!;
const wallet2 = accounts.get("wallet_2")!;

// const assets = simnet.getAssetsMap();
// const mockFt = assets.get('MOCK')!;
// const deployerBalance = mockFt.get(wallet1)!;


// Mock FT contract for testing
const mockFtContract = `${simnet.deployer}.mock-token`;
const marketplaceContract = `${simnet.deployer}.marketplace`;
const adminContract = `${simnet.deployer}.marketplace-admin`;
const fulfillContract = `${simnet.deployer}.marketplace-fulfill`;





// describe("mock token", () => {
  

  
// });

describe("Marketplace Contract Tests", () => {
  
  

  beforeEach(() => {
    // Reset simnet state before each test
    simnet.setEpoch("3.0");
  });

  describe("Initialization and Admin Functions", () => {
    it("should initialize with correct default values", () => {
      const { result: nonce } = simnet.callReadOnlyFn(
        "marketplace", 
        "get-listing-ft-nonce", 
        [], 
        deployer
      );
      expect(nonce).toBeOk(Cl.uint(0));

      const { result: emergencyStop } = simnet.callReadOnlyFn(
        "marketplace", 
        "get-emergency-stop", 
        [], 
        deployer
      );
      expect(emergencyStop).toBeBool(false);

      const { result: feeBps } = simnet.callReadOnlyFn(
        "marketplace", 
        "get-transaction-fee-bps", 
        [], 
        deployer
      );
      expect(feeBps).toBeUint(500); // 5% default
    });

    it("should allow contract owner to set emergency stop", () => {
      const { result } = simnet.callPublicFn(
        "marketplace",
        "set-emergency-stop",
        [Cl.bool(true)],
        deployer
      );
      expect(result).toBeOk(Cl.bool(true));

      const { result: emergencyStop } = simnet.callReadOnlyFn(
        "marketplace", 
        "get-emergency-stop", 
        [], 
        deployer
      );
      expect(emergencyStop).toBeBool(true);
    });

    it("should not allow non-owner to set emergency stop", () => {
      const { result } = simnet.callPublicFn(
        "marketplace",
        "set-emergency-stop",
        [Cl.bool(true)],
        wallet1
      );
      expect(result).toBeErr(Cl.uint(2001)); // ERR_UNAUTHORISED
    });

    it("should allow contract owner to set transaction fee", () => {
      const newFeeBps = 1000; // 10%
      const { result } = simnet.callPublicFn(
        "marketplace",
        "set-transaction-fee-bps",
        [Cl.uint(newFeeBps)],
        deployer
      );
      expect(result).toBeOk(Cl.bool(true));

      const { result: feeBps } = simnet.callReadOnlyFn(
        "marketplace", 
        "get-transaction-fee-bps", 
        [], 
        deployer
      );
      expect(feeBps).toBeUint(newFeeBps);
    });

    it("should calculate fees correctly", () => {
      const paymentAmount = 1000;
      const { result } = simnet.callReadOnlyFn(
        "marketplace",
        "calculate-fee-for-amount",
        [Cl.uint(paymentAmount)],
        deployer
      );
      // Default 5% = 500 bps, so fee = (1000 * 500) / 10000 = 50
      expect(result).toBeUint(50);
    });
  });

  describe("Whitelisting Functions", () => {
    it("should allow contract owner to whitelist asset contracts", () => {
      const { result } = simnet.callPublicFn(
        "marketplace",
        "set-whitelisted",
        [Cl.principal(mockFtContract), Cl.bool(true)],
        deployer
      );
      expect(result).toBeOk(Cl.bool(true));

      const { result: isWhitelisted } = simnet.callReadOnlyFn(
        "marketplace",
        "is-whitelisted",
        [Cl.principal(mockFtContract)],
        deployer
      );
      expect(isWhitelisted).toBeBool(true);
    });

    it("should not allow non-owner to whitelist contracts", () => {
      const { result } = simnet.callPublicFn(
        "marketplace",
        "set-whitelisted",
        [Cl.principal(mockFtContract), Cl.bool(true)],
        wallet1
      );
      expect(result).toBeErr(Cl.uint(2001)); // ERR_UNAUTHORISED
    });

    it("should return false for non-whitelisted contracts", () => {
      const { result: isWhitelisted } = simnet.callReadOnlyFn(
        "marketplace",
        "is-whitelisted",
        [Cl.principal(`${deployer}.non-existent-contract`)],
        deployer
      );
      expect(isWhitelisted).toBeBool(false);
    });
  });

  describe("Contract Owner Management", () => {
    it("should allow current owner to transfer ownership", () => {
      const { result } = simnet.callPublicFn(
        "marketplace",
        "set-contract-owner",
        [Cl.principal(wallet1)],
        deployer
      );
      expect(result).toBeOk(Cl.bool(true));
    });

    it("should not allow non-owner to transfer ownership", () => {
      const { result } = simnet.callPublicFn(
        "marketplace",
        "set-contract-owner",
        [Cl.principal(wallet2)],
        wallet1
      );
      expect(result).toBeErr(Cl.uint(2001)); // ERR_UNAUTHORISED
    });
  });

  

  describe("Listing Creation", () => {
    beforeEach(() => {
      // Whitelist mock FT contract and initialize protocol
      simnet.callPublicFn(
        "marketplace",
        "set-whitelisted",
        [Cl.principal(mockFtContract), Cl.bool(true)],
        simnet.deployer
      );

      simnet.callPublicFn(
        "mock-token", 
        "mint", 
        [Cl.uint(10000000), Cl.principal(wallet1)],
        simnet.deployer
    )
      
    });

    it("should fail to create listing with zero price", () => {
      const listingData = Cl.tuple({
        taker: Cl.none(),
        amt: Cl.uint(100000),
        expiry: Cl.uint(1000),
        price: Cl.uint(0), // Zero price should fail
        "payment-asset-contract": Cl.none()
      });

      const { result } = simnet.callPublicFn(
        "marketplace",
        "list-asset-ft",
        [Cl.contractPrincipal(simnet.deployer, "mock-token"), listingData],
        wallet1
      );
      expect(result).toBeErr(Cl.uint(1001)); // ERR_PRICE_ZERO
    });

    it("should fail to create listing with non-whitelisted asset", () => {
      const listingData = Cl.tuple({
        taker: Cl.none(),
        amt: Cl.uint(100),
        expiry: Cl.uint(1000),
        price: Cl.uint(50),
        "payment-asset-contract": Cl.none()
      });

      const { result } = simnet.callPublicFn(
        "marketplace",
        "list-asset-ft",
        [Cl.contractPrincipal(simnet.deployer, "non-whitelisted-ft"), listingData],
        wallet1
      );
      expect(result).toBeErr(Cl.uint(2007)); // ERR_ASSET_CONTRACT_NOT_WHITELISTED
    });

    it("should fail when contract is paused", () => {
      // Set emergency stop
      simnet.callPublicFn(
        "marketplace",
        "set-emergency-stop",
        [Cl.bool(true)],
        deployer
      );

      const listingData = Cl.tuple({
        taker: Cl.none(),
        amt: Cl.uint(100),
        expiry: Cl.uint(1000),
        price: Cl.uint(50),
        "payment-asset-contract": Cl.none()
      });

      const { result } = simnet.callPublicFn(
        "marketplace",
        "list-asset-ft",
        [Cl.contractPrincipal(deployer, "mock-token"), listingData],
        wallet1
      );
      expect(result).toBeErr(Cl.uint(3000)); // ERR_CONTRACT_PAUSED
    });
  });

  describe("Listing Management", () => {
    let listingId: number;

    beforeEach(() => {
      // Setup for listing tests
      simnet.callPublicFn(
        "marketplace",
        "set-whitelisted",
        [Cl.principal(mockFtContract), Cl.bool(true)],
        deployer
      );
      
      
    });

    it("should allow maker to update their listing", () => {
      // First create a listing (this would need a proper mock FT contract)
      const listingData = Cl.tuple({
        taker: Cl.none(),
        amt: Cl.uint(100000),
        expiry: Cl.uint(1000),
        price: Cl.uint(5), // Zero price should fail
        "payment-asset-contract": Cl.none()
      });

      const { result: listingCreation } = simnet.callPublicFn(
        "marketplace",
        "list-asset-ft",
        [Cl.contractPrincipal(simnet.deployer, "mock-token"), listingData],
        wallet1
      );
      expect(listingCreation).toBeOk(Cl.uint(0)); // (ok listing id)


      listingId = 0; // Assuming successful creation
      
      const { result: UpdateListing } = simnet.callPublicFn(
        "marketplace",
        "update-listing-ft",
        [
          Cl.uint(listingId),
          Cl.principal(mockFtContract),
          Cl.some(Cl.uint(200)), // new amount
          Cl.some(Cl.uint(75)),   // new price
          Cl.none()               // keep same expiry
        ],
        wallet1
      );

      expect(UpdateListing).toBeOk(Cl.uint(0))
      
      // This test assumes the listing exists and wallet1 is the maker
      // In a real scenario, you'd need to create the listing first
    });

    it("should not allow non-maker to update listing", () => {

      const listingData = Cl.tuple({
        taker: Cl.none(),
        amt: Cl.uint(100000),
        expiry: Cl.uint(1000),
        price: Cl.uint(5), // Zero price should fail
        "payment-asset-contract": Cl.none()
      });

      const { result: listingCreation } = simnet.callPublicFn(
        "marketplace",
        "list-asset-ft",
        [Cl.contractPrincipal(simnet.deployer, "mock-token"), listingData],
        wallet1
      );
      expect(listingCreation).toBeOk(Cl.uint(0)); // (ok listing id)
    
      
      const { result: unauthorized_account } = simnet.callPublicFn(
        "marketplace",
        "update-listing-ft",
        [
          Cl.uint(listingId),
          Cl.principal(mockFtContract),
          Cl.some(Cl.uint(200)),
          Cl.some(Cl.uint(75)),
          Cl.none()
        ],
        wallet2 // Different wallet
      );
      expect(unauthorized_account).toBeErr(Cl.uint(2001)); // ERR_UNAUTHORISED
    });

    it("should fail to update non-existent listing", () => {
      const { result } = simnet.callPublicFn(
        "marketplace",
        "update-listing-ft",
        [
          Cl.uint(999), // Non-existent listing
          Cl.principal(mockFtContract),
          Cl.some(Cl.uint(200)),
          Cl.some(Cl.uint(75)),
          Cl.none()
        ],
        wallet1
      );
      expect(result).toBeErr(Cl.uint(2000)); // ERR_UNKNOWN_LISTING
    });
  });

  describe("Listing buy", () => {
    let listingId: number;

    beforeEach(() => {
      // Setup for listing tests
      simnet.callPublicFn(
        "marketplace",
        "set-whitelisted",
        [Cl.principal(mockFtContract), Cl.bool(true)],
        deployer
      );
      
      
    });

    it("should allow user to buy their listing", () => {
      // First create a listing (this would need a proper mock FT contract)
      const listingData = Cl.tuple({
        taker: Cl.none(),
        amt: Cl.uint(100000),
        expiry: Cl.uint(1000),
        price: Cl.uint(5), // Zero price should fail
        "payment-asset-contract": Cl.none()
      });

      const { result: listingCreation } = simnet.callPublicFn(
        "marketplace",
        "list-asset-ft",
        [Cl.contractPrincipal(simnet.deployer, "mock-token"), listingData],
        wallet1
      );
      expect(listingCreation).toBeOk(Cl.uint(0)); // (ok listing id)


      listingId = 0; // Assuming successful creation
      
      const { result: UpdateListing } = simnet.callPublicFn(
        "marketplace",
        "update-listing-ft",
        [
          Cl.uint(listingId),
          Cl.principal(mockFtContract),
          Cl.some(Cl.uint(200)), // new amount
          Cl.some(Cl.uint(75)),   // new price
          Cl.none()               // keep same expiry
        ],
        wallet1
      );

      expect(UpdateListing).toBeOk(Cl.uint(0))
      
      // This test assumes the listing exists and wallet1 is the maker
      // In a real scenario, you'd need to create the listing first
    });

    it("should not allow non-maker to update listing", () => {

      const listingData = Cl.tuple({
        taker: Cl.none(),
        amt: Cl.uint(100000),
        expiry: Cl.uint(1000),
        price: Cl.uint(5), // Zero price should fail
        "payment-asset-contract": Cl.none()
      });

      const { result: listingCreation } = simnet.callPublicFn(
        "marketplace",
        "list-asset-ft",
        [Cl.contractPrincipal(simnet.deployer, "mock-token"), listingData],
        wallet1
      );
      expect(listingCreation).toBeOk(Cl.uint(0)); // (ok listing id)
    
      
      const { result: unauthorized_account } = simnet.callPublicFn(
        "marketplace",
        "update-listing-ft",
        [
          Cl.uint(listingId),
          Cl.principal(mockFtContract),
          Cl.some(Cl.uint(200)),
          Cl.some(Cl.uint(75)),
          Cl.none()
        ],
        wallet2 // Different wallet
      );
      expect(unauthorized_account).toBeErr(Cl.uint(2001)); // ERR_UNAUTHORISED
    });

    it("should fail to update non-existent listing", () => {
      const { result } = simnet.callPublicFn(
        "marketplace",
        "update-listing-ft",
        [
          Cl.uint(999), // Non-existent listing
          Cl.principal(mockFtContract),
          Cl.some(Cl.uint(200)),
          Cl.some(Cl.uint(75)),
          Cl.none()
        ],
        wallet1
      );
      expect(result).toBeErr(Cl.uint(2000)); // ERR_UNKNOWN_LISTING
    });
  });

  describe("Listing Retrieval", () => {
    it("should return none for non-existent listing", () => {
      const { result } = simnet.callReadOnlyFn(
        "marketplace",
        "get-listing-map",
        [Cl.uint(999)],
        deployer
      );
      expect(result).toBeNone();
    });
  });

  describe("Error Constants Validation", () => {
    it("should have correct error codes defined", () => {
      // Test that error constants are properly defined by triggering known errors
      
      // Test ERR_PRICE_ZERO
      const listingData = Cl.tuple({
        taker: Cl.none(),
        amt: Cl.uint(100),
        expiry: Cl.uint(1000),
        price: Cl.uint(0),
        "payment-asset-contract": Cl.none()
      });

      // First whitelist the contract
      simnet.callPublicFn(
        "marketplace",
        "set-whitelisted",
        [Cl.principal(mockFtContract), Cl.bool(true)],
        deployer
      );

      const { result } = simnet.callPublicFn(
        "marketplace",
        "list-asset-ft",
        [Cl.contractPrincipal(deployer, "mock-token"), listingData],
        wallet1
      );
      expect(result).toBeErr(Cl.uint(1001)); // ERR_PRICE_ZERO

      // Test ERR_UNAUTHORISED for non-owner trying to set emergency stop
      const { result: unauthorizedResult } = simnet.callPublicFn(
        "marketplace",
        "set-emergency-stop",
        [Cl.bool(true)],
        wallet1
      );
      expect(unauthorizedResult).toBeErr(Cl.uint(2001)); // ERR_UNAUTHORISED
    });
  });

  describe("Fee Calculation Edge Cases", () => {
    it("should handle zero payment amount", () => {
      const { result } = simnet.callReadOnlyFn(
        "marketplace",
        "calculate-fee-for-amount",
        [Cl.uint(0)],
        deployer
      );
      expect(result).toBeUint(0);
    });

    it("should handle large payment amounts", () => {
      const largeAmount = 1000000;
      const { result } = simnet.callReadOnlyFn(
        "marketplace",
        "calculate-fee-for-amount",
        [Cl.uint(largeAmount)],
        deployer
      );
      // 5% of 1,000,000 = 50,000
      expect(result).toBeUint(50000);
    });

    it("should handle custom fee percentages", () => {
      // Set fee to 10% (1000 basis points)
      simnet.callPublicFn(
        "marketplace",
        "set-transaction-fee-bps",
        [Cl.uint(1000)],
        deployer
      );

      const { result } = simnet.callReadOnlyFn(
        "marketplace",
        "calculate-fee-for-amount",
        [Cl.uint(1000)],
        deployer
      );
      // 10% of 1000 = 100
      expect(result).toBeUint(100);
    });
  });

  describe("Protocol Role Validation", () => {
    it("should validate protocol caller roles", () => {
      // Initialize protocol first
      

      // Test protocol role validation (this would require proper contract-caller context)
      const { result } = simnet.callReadOnlyFn(
        "marketplace",
        "is-protocol-caller",
        [Cl.buffer(new Uint8Array([0x00])), Cl.principal(adminContract)],
        deployer
      );
      // This test depends on contract-caller context which is complex to mock
      expect(result).toBeOk(Cl.bool(true))
    });
  });

  describe("Emergency Stop Functionality", () => {
    it("should prevent all operations when paused", () => {
      // Enable emergency stop
      simnet.callPublicFn(
        "marketplace",
        "set-emergency-stop",
        [Cl.bool(true)],
        deployer
      );

      // Try to whitelist (should fail)
      const { result } = simnet.callPublicFn(
        "marketplace",
        "set-whitelisted",
        [Cl.principal(mockFtContract), Cl.bool(true)],
        deployer
      );
      expect(result).toBeErr(Cl.uint(3000)); // ERR_CONTRACT_PAUSED
    });

    it("should resume operations when unpaused", () => {
      // Enable then disable emergency stop
      simnet.callPublicFn(
        "marketplace",
        "set-emergency-stop",
        [Cl.bool(true)],
        deployer
      );
      
      simnet.callPublicFn(
        "marketplace",
        "set-emergency-stop",
        [Cl.bool(false)],
        deployer
      );

      // Now operations should work
      const { result } = simnet.callPublicFn(
        "marketplace",
        "set-whitelisted",
        [Cl.principal(mockFtContract), Cl.bool(true)],
        deployer
      );
      expect(result).toBeOk(Cl.bool(true));
    });
  });
});