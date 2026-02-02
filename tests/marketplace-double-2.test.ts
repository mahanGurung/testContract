import { describe, expect, it, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = simnet.deployer;
const wallet1 = accounts.get("wallet_1")!;

const marketplace = "marketplace";
const tokenA = `${deployer}.mock-token-a`;
const mockToken = `${deployer}.mock-token`;
const marketplaceFulfill = "marketplace-fulfill";

describe("Milestone completion works as expected", () => {
  beforeEach(() => {
    simnet.setEpoch("3.0");

    // Whitelist the token for the test
    simnet.callPublicFn(
      marketplace,
      "set-whitelisted",
      [Cl.principal(tokenA), Cl.bool(true), Cl.uint(4), Cl.some(Cl.uint(1000000000))],
      deployer
    );
  });

  it("should allow a user to list an asset, reserve it, and claim it after milestone completion", () => {
    // 1. List the asset
    const listing = Cl.tuple({
      amt: Cl.uint(1000000000),
      expiry: Cl.uint(10000),
      price: Cl.uint(4),
      "payment-asset-contract": Cl.none()
    });

    const listAssetResponse = simnet.callPublicFn(
      marketplace,
      "list-asset-ft",
      [
        Cl.contractPrincipal(deployer, "mock-token-a"),
        Cl.contractPrincipal(deployer, "mock-token-a"),
        listing
      ],
      deployer
    );
    expect(listAssetResponse.result).toBeOk(Cl.bool(true));

    // 2. Reserve a portion of the asset (less than a full milestone)
    const reservePartialResponse = simnet.callPublicFn(
      marketplaceFulfill,
      "reserve-listing-ft-stx",
      [
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.uint(249999999)
      ],
      wallet1
    );
    expect(reservePartialResponse.result).toBeOk(Cl.bool(true));
    
    // 4. Claim the purchased asset after milestone completion
    const claimResponse = simnet.callPublicFn(
      marketplace,
      "claim-after-success",
      [
        Cl.contractPrincipal(deployer, "mock-token-a"),
        Cl.principal(deployer)
      ],
      wallet1
    );

    expect(claimResponse.result).toBeOk(Cl.bool(true));
  });

  it("should not allow a user to claim if milestone is not complete", () => {
    // 1. List the asset
    const listing = Cl.tuple({
      amt: Cl.uint(1000000000),
      expiry: Cl.uint(10000),
      price: Cl.uint(4),
      "payment-asset-contract": Cl.none()
    });

    const listAssetResponse = simnet.callPublicFn(
      marketplace,
      "list-asset-ft",
      [
        Cl.contractPrincipal(deployer, "mock-token-a"),
        Cl.contractPrincipal(deployer, "mock-token-a"),
        listing
      ],
      deployer
    );
    expect(listAssetResponse.result).toBeOk(Cl.bool(true));

    // 2. Reserve a portion of the asset (not enough to complete a milestone)
    const reservePartialResponse = simnet.callPublicFn(
      marketplaceFulfill,
      "reserve-listing-ft-stx",
      [
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.uint(1000) // Reserve a small amount
      ],
      wallet1
    );
    expect(reservePartialResponse.result).toBeOk(Cl.bool(true));

    // 3. Try to claim the purchased asset. This should fail.
    const claimResponse = simnet.callPublicFn(
      marketplace,
      "claim-after-success",
      [
        Cl.contractPrincipal(deployer, "mock-token-a"),
        Cl.principal(deployer)
      ],
      wallet1
    );

    // ERR_MILESTONE_NOT_COMP (err u2012)
    expect(claimResponse.result).toBeErr(Cl.uint(2012));
  });
});

describe("cancel-listing-ft", () => {
  beforeEach(() => {
      simnet.setEpoch("3.0");

      // Whitelist the token for the test
      simnet.callPublicFn(
          marketplace,
          "set-whitelisted",
          [Cl.principal(tokenA), Cl.bool(true), Cl.uint(4), Cl.some(Cl.uint(1000000000))], 
          deployer
      );
  });

  it("should allow maker to cancel a listing", () => {
      // 1. List the asset
      const listing = Cl.tuple({
          amt: Cl.uint(1000000000),
          expiry: Cl.uint(10000),
          price: Cl.uint(4),
          "payment-asset-contract": Cl.none()
      });

      const listAssetResponse = simnet.callPublicFn(
          marketplace,
          "list-asset-ft",
          [
              Cl.contractPrincipal(deployer, "mock-token-a"),
              Cl.contractPrincipal(deployer, "mock-token-a"),
              listing
          ],
          deployer
      );
      expect(listAssetResponse.result).toBeOk(Cl.bool(true));

      // verify listing exists
      let getListingMap = simnet.callReadOnlyFn(
          marketplace,
          "get-listing-map",
          [Cl.principal(deployer), Cl.contractPrincipal(deployer, "mock-token-a")],
          deployer
      );
      expect(getListingMap.result).not.toBeNull();

      // 2. Cancel the listing
      const cancelListingResponse = simnet.callPublicFn(
          marketplace,
          "cancel-listing-ft",
          [Cl.contractPrincipal(deployer, "mock-token-a")],
          deployer
      );
      expect(cancelListingResponse.result).toBeOk(Cl.bool(true));

      // 3. Verify the listing is removed
      getListingMap = simnet.callReadOnlyFn(
          marketplace,
          "get-listing-map",
          [Cl.principal(deployer), Cl.contractPrincipal(deployer, "mock-token-a")],
          deployer
      );
      expect(getListingMap.result).toBeNone();

      // 4. Verify FTs are returned by checking the event
      // expect(cancelListingResponse.events).toHaveLength(2); // print and transfer
      // const transferEvent = cancelListingResponse.events.find(e => e.event === "ft_transfer_event")?.data;
      // expect(transferEvent).toBeDefined();
      // expect(transferEvent.asset_identifier).toBe(Cl.contractPrincipal(deployer, "mock-token-a").toString());
      // expect(transferEvent.sender).toBe(Cl.contractPrincipal(deployer, marketplace).toString());
      // expect(transferEvent.recipient).toBe(deployer);
      // expect(transferEvent.amount).toBe("1000000000");
  });
});

describe("Fungible token payments", () => {
  beforeEach(() => {
      simnet.setEpoch("3.0");

      // Whitelist asset token
      simnet.callPublicFn(
          marketplace,
          "set-whitelisted",
          [Cl.principal(tokenA), Cl.bool(true), Cl.uint(4), Cl.some(Cl.uint(1000000000))],
          deployer
      );

      // Whitelist payment token
      simnet.callPublicFn(
          marketplace,
          "set-whitelisted",
          [Cl.principal(mockToken), Cl.bool(true), Cl.uint(0), Cl.none()], // amount and divide are not used for payment tokens
          deployer
      );

      // Mint some payment tokens for wallet1
      simnet.callPublicFn(
          "mock-token",
          "mint",
          [Cl.uint(1000000), Cl.principal(wallet1)],
          deployer
      );
  });

  it("should allow reserving an asset using a whitelisted FT", () => {
      // 1. List the asset with FT as payment
      const listing = Cl.tuple({
          amt: Cl.uint(1000000000),
          expiry: Cl.uint(10000),
          price: Cl.uint(2), // price in mock-token
          "payment-asset-contract": Cl.some(Cl.principal(mockToken))
      });

      const listAssetResponse = simnet.callPublicFn(
          marketplace,
          "list-asset-ft",
          [
              Cl.contractPrincipal(deployer, "mock-token-a"),
              Cl.contractPrincipal(deployer, "mock-token-a"),
              listing
          ],
          deployer
      );
      expect(listAssetResponse.result).toBeOk(Cl.bool(true));

      // 2. Reserve a portion of the asset
      const reserveAmount = 1000;
      const reserveResponse = simnet.callPublicFn(
        marketplaceFulfill,
        "fulfil-ft-listing-ft",
        [
          Cl.contractPrincipal(deployer, 'mock-token-a'),
          Cl.contractPrincipal(deployer, 'mock-token-a'),
          Cl.contractPrincipal(deployer, 'mock-token'),
          Cl.uint(reserveAmount)
        ],
        wallet1
      );

      expect(reserveResponse.result).toBeOk(Cl.bool(true));

      
  });
});