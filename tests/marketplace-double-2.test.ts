import { describe, expect, it, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = simnet.deployer;
const wallet1 = accounts.get("wallet_1")!;
const wallet2 = accounts.get("wallet_2")!;
const wallet3 = accounts.get("wallet_3")!;
const wallet4 = accounts.get("wallet_4")!;

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

  it("should allow the asset owner to claim after milestone completion", () => {
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

    // 2. Reserve enough of the asset to complete a milestone (25% of 10^9 = 2.5 * 10^8)
    const reserveAmount = 249999999;
    const reserveResponse = simnet.callPublicFn(
      marketplaceFulfill,
      "reserve-listing-ft-stx",
      [
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.uint(reserveAmount)
      ],
      wallet1
    );
    expect(reserveResponse.result).toBeOk(Cl.bool(true));

    // 3. Asset owner claims after milestone completion
    const assetOwnerClaimResponse = simnet.callPublicFn(
      marketplace,
      "asset-owner-claim-after-milestone-comp",
      [
        Cl.contractPrincipal(deployer, "mock-token-a"), // ft-asset-contract
        Cl.contractPrincipal(deployer, "mock-token-a"), // ft-asset-contract

      ],
      deployer
    );
    expect(assetOwnerClaimResponse.result).toBeOk(Cl.bool(true));
  });

  it("should allow users to buy up to milestone 3 and allow the asset owner to claim", () => {
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

    const milestoneAmount1 = 249999999; // Amount to complete one milestone
    const milestoneCompleltionAmount = 250000000;

    // 2. Wallet1 reserves for Milestone 1
    const reserve1Response = simnet.callPublicFn(
      marketplaceFulfill,
      "reserve-listing-ft-stx",
      [
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.uint(milestoneAmount1)
      ],
      wallet1
    );
    expect(reserve1Response.result).toBeOk(Cl.bool(true));

    // 3. Wallet1 reserves for Milestone 2
    const reserve2Response = simnet.callPublicFn(
      marketplaceFulfill,
      "reserve-listing-ft-stx",
      [
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.uint(milestoneCompleltionAmount)
      ],
      wallet2
    );
    expect(reserve2Response.result).toBeOk(Cl.bool(true));

    // 4. Wallet1 reserves for Milestone 3
    const reserve3Response = simnet.callPublicFn(
      marketplaceFulfill,
      "reserve-listing-ft-stx",
      [
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.uint(milestoneCompleltionAmount)
      ],
      wallet3
    );
    expect(reserve3Response.result).toBeOk(Cl.bool(true));

    // 5. Asset owner claims after milestone 3 completion
    const assetOwnerClaimResponse = simnet.callPublicFn(
      marketplace,
      "asset-owner-claim-after-milestone-comp",
      [
        Cl.contractPrincipal(deployer, "mock-token-a"),
        Cl.contractPrincipal(deployer, "mock-token-a"),
      ],
      deployer
    );
    expect(assetOwnerClaimResponse.result).toBeOk(Cl.bool(true));
  });

  it("should allow users to buy up to milestone 4 (full completion) and allow the asset owner to claim", () => {
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

    const milestoneAmount1 = 249999999; // Amount to complete one milestone
    const milestoneCompleltionAmount = 250000000;


    // 2. Wallet1 reserves for Milestone 1
    let reserveResponse = simnet.callPublicFn(
      marketplaceFulfill,
      "reserve-listing-ft-stx",
      [
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.uint(milestoneAmount1)
      ],
      wallet1
    );
    expect(reserveResponse.result).toBeOk(Cl.bool(true));

    reserveResponse = simnet.callReadOnlyFn(
      marketplace,
      "get-listing-map",
      [
        Cl.principal(deployer),
        Cl.contractPrincipal(deployer, 'mock-token-a')
      ],
      deployer
    )

    console.log("Final listing state 1: ", reserveResponse.result.value);

    // 3. Wallet1 reserves for Milestone 2
    reserveResponse = simnet.callPublicFn(
      marketplaceFulfill,
      "reserve-listing-ft-stx",
      [
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.uint(milestoneCompleltionAmount)
      ],
      wallet2
    );
    expect(reserveResponse.result).toBeOk(Cl.bool(true));

    reserveResponse = simnet.callReadOnlyFn(
      marketplace,
      "get-listing-map",
      [
        Cl.principal(deployer),
        Cl.contractPrincipal(deployer, 'mock-token-a')
      ],
      deployer
    )

    console.log("Final listing state 2: ", reserveResponse.result.value);

    // 4. Wallet1 reserves for Milestone 3
    reserveResponse = simnet.callPublicFn(
      marketplaceFulfill,
      "reserve-listing-ft-stx",
      [
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.uint(milestoneCompleltionAmount)
      ],
      wallet3
    );
    expect(reserveResponse.result).toBeOk(Cl.bool(true));


    reserveResponse = simnet.callReadOnlyFn(
      marketplace,
      "get-listing-map",
      [
        Cl.principal(deployer),
        Cl.contractPrincipal(deployer, 'mock-token-a')
      ],
      deployer
    )

    console.log("Final listing state 3: ", reserveResponse.result.value);

    // 5. Wallet1 reserves for Milestone 4 (full completion)
    reserveResponse = simnet.callPublicFn(
      marketplaceFulfill,
      "reserve-listing-ft-stx",
      [
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.uint(milestoneAmount1)
      ],
      wallet4
    );
    expect(reserveResponse.result).toBeOk(Cl.bool(true));


    reserveResponse = simnet.callReadOnlyFn(
      marketplace,
      "get-listing-map",
      [
        Cl.principal(deployer),
        Cl.contractPrincipal(deployer, 'mock-token-a')
      ],
      deployer
    )

    console.log("Final listing state 4: ", reserveResponse.result.value);

    // 5. Wallet1 reserves for Milestone 4 (full completion)
    reserveResponse = simnet.callPublicFn(
      marketplaceFulfill,
      "reserve-listing-ft-stx",
      [
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.uint(2)
      ],
      wallet4
    );
    expect(reserveResponse.result).toBeOk(Cl.bool(true));

    reserveResponse = simnet.callReadOnlyFn(
      marketplace,
      "get-listing-map",
      [
        Cl.principal(deployer),
        Cl.contractPrincipal(deployer, 'mock-token-a')
      ],
      deployer
    )

    console.log("Final listing state 4: ", reserveResponse.result.value);

    // 6. Asset owner claims after all milestones completion
    const assetOwnerClaimResponse = simnet.callPublicFn(
      marketplace,
      "asset-owner-claim-after-milestone-comp",
      [
        Cl.contractPrincipal(deployer, "mock-token-a"),
        Cl.contractPrincipal(deployer, "mock-token-a"),
      ],
      deployer
    );
    expect(assetOwnerClaimResponse.result).toBeOk(Cl.bool(true));
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

describe("asset-owner-claim-after-milestone-comp", () => {
  beforeEach(() => {
    simnet.setEpoch("3.0");

    // Whitelist the token for the test
    simnet.callPublicFn(
      marketplace,
      "set-whitelisted",
      [Cl.principal(tokenA), Cl.bool(true), Cl.uint(4), Cl.some(Cl.uint(1000000000))],
      deployer
    );

    // List the asset
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
  });

  it("should not allow a non-owner to call and trigger payout", () => {
    // Reserve enough to complete a milestone
    const reserveAmount = 249999999;
    const reserveResponse = simnet.callPublicFn(
      marketplaceFulfill,
      "reserve-listing-ft-stx",
      [
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.uint(reserveAmount)
      ],
      wallet1
    );
    expect(reserveResponse.result).toBeOk(Cl.bool(true));

    // wallet1 (not the owner) calls asset-owner-claim-after-milestone-comp
    const assetOwnerClaimResponse = simnet.callPublicFn(
      marketplace,
      "asset-owner-claim-after-milestone-comp",
      [
        Cl.contractPrincipal(deployer, "mock-token-a"),
        Cl.contractPrincipal(deployer, "mock-token-a")

      ],
      wallet1 // Called by non-owner
    );
    expect(assetOwnerClaimResponse.result).toBeErr(Cl.uint(1003));
  });

  it("should fail if there is no amount to collect", () => {
    // Attempt to claim without any reservations made
    const assetOwnerClaimResponse = simnet.callPublicFn(
      marketplace,
      "asset-owner-claim-after-milestone-comp",
      [
        Cl.contractPrincipal(deployer, "mock-token-a"),
        Cl.contractPrincipal(deployer, "mock-token-a")
      ],
      deployer
    );
    // ERR_CLAIM_AMOUNT_ZERO (u2015) is expected but ERR_MILESTONE_NOT_COMP (u2012) is returned first
    expect(assetOwnerClaimResponse.result).toBeErr(Cl.uint(2012));
  });

  it("should fail if milestone is 0 (no reservations)", () => {
    // Attempt to claim before any milestone is completed
    const assetOwnerClaimResponse = simnet.callPublicFn(
      marketplace,
      "asset-owner-claim-after-milestone-comp",
      [
        Cl.contractPrincipal(deployer, "mock-token-a"),
        Cl.contractPrincipal(deployer, "mock-token-a")
      ],
      deployer
    );
    // ERR_MILESTONE_NOT_COMP (err u2012)
    expect(assetOwnerClaimResponse.result).toBeErr(Cl.uint(2012));
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

      // Mint some payment tokens for wallets
      simnet.callPublicFn(
          "mock-token",
          "mint",
          [Cl.uint(1000000000), Cl.principal(wallet1)],
          deployer
      );
      simnet.callPublicFn(
          "mock-token",
          "mint",
          [Cl.uint(1000000000), Cl.principal(wallet2)],
          deployer
      );
      simnet.callPublicFn(
          "mock-token",
          "mint",
          [Cl.uint(1000000000), Cl.principal(wallet3)],
          deployer
      );
      simnet.callPublicFn(
          "mock-token",
          "mint",
          [Cl.uint(1000000000), Cl.principal(wallet4)],
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

  it("should allow a user to claim FT payments after milestone completion", () => {
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

    // 2. Reserve enough to complete a milestone (25% of 10^9 = 2.5 * 10^8)
    const reserveAmount = 249999999;
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

    // 3. Claim the purchased asset after milestone completion
    const claimResponse = simnet.callPublicFn(
      marketplace,
      "claim-after-success",
      [
        Cl.contractPrincipal(deployer, "mock-token-a"), // Asset contract
        Cl.principal(deployer) // Asset owner
      ],
      wallet1
    );
    expect(claimResponse.result).toBeOk(Cl.bool(true));
  });

  it("should allow a user to claim FT payments if unsuccessful (milestone not met)", () => {
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

    // 2. Reserve an amount that does NOT complete a milestone
    const reserveAmount = 1000; // Small amount, not enough for milestone
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

    // 3. Attempt to claim as unsuccessful
    const claimUnsuccessfulResponse = simnet.callPublicFn(
      marketplace,
      "claim-but-no-success-ft",
      [
        Cl.contractPrincipal(deployer, "mock-token-a"), // Asset contract
        Cl.principal(deployer), // Asset owner
        Cl.contractPrincipal(deployer, "mock-token") // Payment contract
      ],
      wallet1
    );
    expect(claimUnsuccessfulResponse.result).toBeOk(Cl.bool(true));
  });

  // New test cases for milestone 3 and 4 completion with FT payments and asset owner claim
  it("should allow FT payments up to milestone 3 and allow the asset owner to claim", () => {
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

    const milestoneAmount1 = 249999999; // Amount to complete one milestone
    const milestoneCompleltionAmount = 250000000;

    // 2. Wallet1 reserves for Milestone 1
    const reserve1Response = simnet.callPublicFn(
      marketplaceFulfill,
      "fulfil-ft-listing-ft",
      [
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.contractPrincipal(deployer, 'mock-token'),
        Cl.uint(milestoneAmount1)
      ],
      wallet1
    );
    expect(reserve1Response.result).toBeOk(Cl.bool(true));

    // 3. Wallet2 reserves for Milestone 2
    const reserve2Response = simnet.callPublicFn(
      marketplaceFulfill,
      "fulfil-ft-listing-ft",
      [
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.contractPrincipal(deployer, 'mock-token'),
        Cl.uint(milestoneCompleltionAmount)
      ],
      wallet2
    );
    expect(reserve2Response.result).toBeOk(Cl.bool(true));

    // 4. Wallet3 reserves for Milestone 3
    const reserve3Response = simnet.callPublicFn(
      marketplaceFulfill,
      "fulfil-ft-listing-ft",
      [
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.contractPrincipal(deployer, 'mock-token'),
        Cl.uint(milestoneCompleltionAmount)
      ],
      wallet3
    );
    expect(reserve3Response.result).toBeOk(Cl.bool(true));

    // 5. Asset owner claims after milestone 3 completion
    const assetOwnerClaimResponse = simnet.callPublicFn(
      marketplace,
      "asset-owner-claim-after-milestone-comp-ft",
      [
        Cl.contractPrincipal(deployer, "mock-token-a"),
        Cl.contractPrincipal(deployer, "mock-token-a"),
        Cl.contractPrincipal(deployer, "mock-token")
      ],
      deployer
    );
    expect(assetOwnerClaimResponse.result).toBeOk(Cl.bool(true));
  });

  it("should allow FT payments up to milestone 4 (full completion) and allow the asset owner to claim", () => {
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

    const milestoneAmount1 = 249999999; // Amount to complete one milestone
    const milestoneCompleltionAmount = 250000000;

    // 2. Wallet1 reserves for Milestone 1
    let reserveResponse = simnet.callPublicFn(
      marketplaceFulfill,
      "fulfil-ft-listing-ft",
      [
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.contractPrincipal(deployer, 'mock-token'),
        Cl.uint(milestoneAmount1)
      ],
      wallet1
    );
    expect(reserveResponse.result).toBeOk(Cl.bool(true));

    // 3. Wallet2 reserves for Milestone 2
    reserveResponse = simnet.callPublicFn(
      marketplaceFulfill,
      "fulfil-ft-listing-ft",
      [
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.contractPrincipal(deployer, 'mock-token'),
        Cl.uint(milestoneCompleltionAmount)
      ],
      wallet2
    );
    expect(reserveResponse.result).toBeOk(Cl.bool(true));

    // 4. Wallet3 reserves for Milestone 3
    reserveResponse = simnet.callPublicFn(
      marketplaceFulfill,
      "fulfil-ft-listing-ft",
      [
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.contractPrincipal(deployer, 'mock-token'),
        Cl.uint(milestoneCompleltionAmount)
      ],
      wallet3
    );
    expect(reserveResponse.result).toBeOk(Cl.bool(true));

    // 5. Wallet4 reserves for Milestone 4 (full completion)
    reserveResponse = simnet.callPublicFn(
      marketplaceFulfill,
      "fulfil-ft-listing-ft",
      [
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.contractPrincipal(deployer, 'mock-token'),
        Cl.uint(milestoneAmount1) // Using milestoneAmount1 to reach total amount close to 1e9
      ],
      wallet4
    );
    expect(reserveResponse.result).toBeOk(Cl.bool(true));

    // 6. Asset owner claims after all milestones completion
    const assetOwnerClaimResponse = simnet.callPublicFn(
      marketplace,
      "asset-owner-claim-after-milestone-comp-ft",
      [
        Cl.contractPrincipal(deployer, "mock-token-a"),
        Cl.contractPrincipal(deployer, "mock-token-a"),
        Cl.contractPrincipal(deployer, "mock-token")
      ],
      deployer
    );
    expect(assetOwnerClaimResponse.result).toBeOk(Cl.bool(true));
  });
});

describe("Error Cases", () => {
  beforeEach(() => {
    simnet.setEpoch("3.0");

    // Whitelist the token for the test
    // simnet.callPublicFn(
    //   marketplace,
    //   "set-whitelisted",
    //   [Cl.principal(tokenA), Cl.bool(true), Cl.uint(4), Cl.some(Cl.uint(1000000000))],
    //   deployer
    // );
  });

  it("should not allow a non-maker to update a listing", () => {
    simnet.callPublicFn(
      marketplace,
      "set-whitelisted",
      [Cl.principal(tokenA), Cl.bool(true), Cl.uint(4), Cl.some(Cl.uint(1000000000))],
      deployer
    );

    // 1. List the asset by deployer
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

    // 2. Try to update the listing as wallet1 (non-maker) 
    const updateListingResponse = simnet.callPublicFn(
      marketplace,
      "update-listing-ft",
      [
        Cl.contractPrincipal(deployer, "mock-token-a"),
        Cl.uint(10001) // New expiry
      ],
      wallet1 // Non-maker caller
    );
    expect(updateListingResponse.result).toBeErr(Cl.uint(2000)); // ERR_UNAUTHORISED (2001) or ERR_UNKNOWN_LISTING (2000) if the user has not make any listings
  });

  it("should not allow a non-maker to cancel a listing", () => {

    simnet.callPublicFn(
      marketplace,
      "set-whitelisted",
      [Cl.principal(tokenA), Cl.bool(true), Cl.uint(4), Cl.some(Cl.uint(1000000000))],
      deployer
    );
    // 1. List the asset by deployer
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

    // 2. Try to cancel the listing as wallet1 (non-maker)
    const cancelListingResponse = simnet.callPublicFn(
      marketplace,
      "cancel-listing-ft",
      [Cl.contractPrincipal(deployer, "mock-token-a")],
      wallet1 // Non-maker caller
    );
    expect(cancelListingResponse.result).toBeErr(Cl.uint(2000)); // ERR_UNAUTHORISED or ERR_UNKNOWN_LISTING (2000) if the user has not make any listings
  });

  it("should not allow listing an asset with zero price", () => {

    simnet.callPublicFn(
      marketplace,
      "set-whitelisted",
      [Cl.principal(tokenA), Cl.bool(true), Cl.uint(4), Cl.some(Cl.uint(1000000000))],
      deployer
    );

    const listing = Cl.tuple({
      amt: Cl.uint(1000000000),
      expiry: Cl.uint(10000),
      price: Cl.uint(0), // Zero price
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
    expect(listAssetResponse.result).toBeErr(Cl.uint(1001)); // ERR_PRICE_ZERO
  });

  it("should not allow listing an asset with zero amount", () => {



    simnet.callPublicFn(
      marketplace,
      "set-whitelisted",
      [Cl.principal(tokenA), Cl.bool(true), Cl.uint(4), Cl.some(Cl.uint(1000000000))],
      deployer
    );

    const listing = Cl.tuple({
      amt: Cl.uint(0), // Zero amount
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
    expect(listAssetResponse.result).toBeErr(Cl.uint(1004)); // ERR_AMOUNT_ZERO (1002) or ERR_AMOUNT_NOT_EQUAL (1004)
  });

  it("should not allow asset owner to claim zero collected amount even if all milestones are complete", () => {

    simnet.callPublicFn(
      marketplace,
      "set-whitelisted",
      [Cl.principal(tokenA), Cl.bool(true), Cl.uint(4), Cl.some(Cl.uint(1000000000))],
      deployer
    );

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

    const milestoneAmount = 249999999;

    // 2. Wallet1 reserves for all 4 milestones
    let reserveResponse = simnet.callPublicFn(
      marketplaceFulfill,
      "reserve-listing-ft-stx",
      [
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.uint(milestoneAmount)
      ],
      wallet1
    );
    expect(reserveResponse.result).toBeOk(Cl.bool(true));

    reserveResponse = simnet.callPublicFn(
      marketplaceFulfill,
      "reserve-listing-ft-stx",
      [
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.uint(milestoneAmount)
      ],
      wallet2
    );
    expect(reserveResponse.result).toBeOk(Cl.bool(true));

    reserveResponse = simnet.callPublicFn(
      marketplaceFulfill,
      "reserve-listing-ft-stx",
      [
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.uint(milestoneAmount)
      ],
      wallet3
    );
    expect(reserveResponse.result).toBeOk(Cl.bool(true));

    reserveResponse = simnet.callPublicFn(
      marketplaceFulfill,
      "reserve-listing-ft-stx",
      [
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.contractPrincipal(deployer, 'mock-token-a'),
        Cl.uint(milestoneAmount)
      ],
      wallet4
    );
    expect(reserveResponse.result).toBeOk(Cl.bool(true));

    // 3. Asset owner claims all collected amount for the first time
    const initialClaimResponse = simnet.callPublicFn(
      marketplace,
      "asset-owner-claim-after-milestone-comp",
      [
        Cl.contractPrincipal(deployer, "mock-token-a"),
        Cl.contractPrincipal(deployer, "mock-token-a"),
      ],
      deployer
    );
    expect(initialClaimResponse.result).toBeOk(Cl.bool(true));

    // 4. Try to claim again when collected amount is zero
    const secondClaimResponse = simnet.callPublicFn(
      marketplace,
      "asset-owner-claim-after-milestone-comp",
      [
        Cl.contractPrincipal(deployer, "mock-token-a"),
        Cl.contractPrincipal(deployer, "mock-token-a"),
      ],
      deployer
    );
    expect(secondClaimResponse.result).toBeErr(Cl.uint(2015)); // ERR_CLAIM_AMOUNT_ZERO
  });
});