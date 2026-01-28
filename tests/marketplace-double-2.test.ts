import { describe, expect, it, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = simnet.deployer;
const wallet1 = accounts.get("wallet_1")!;

const marketplace = "marketplace";
const tokenA = `${deployer}.mock-token-a`;

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
      "marketplace-fulfill",
      "reserve-listing-ft-stx",
      [
        Cl.principal(tokenA),
        Cl.contractPrincipal(deployer, "mock-token-a"),
        Cl.uint(249999998)
      ],
      wallet1
    );
    expect(reservePartialResponse.result).toBeOk(Cl.bool(true));

    // 3. Reserve the final portion to complete the milestone
    const reserveFinalResponse = simnet.callPublicFn(
      "marketplace-fulfill",
      "reserve-listing-ft-stx",
      [
        Cl.principal(tokenA),
        Cl.contractPrincipal(deployer, "mock-token-a"),
        Cl.uint(2)
      ],
      wallet1
    );
    expect(reserveFinalResponse.result).toBeOk(Cl.bool(true));
    
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
});
