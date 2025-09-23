
import { describe, expect, it, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";


const accounts = simnet.getAccounts();
const deployer = simnet.deployer;
const address1 = accounts.get("wallet_1")!;
const address2 = accounts.get("wallet_2")!;

const mockFtContract = `${simnet.deployer}.mock-token`;
const fulfillContract = `${simnet.deployer}.marketplace-fulfill`;



/*
  The test below is an example. To learn more, read the testing documentation here:
  https://docs.hiro.so/stacks/clarinet-js-sdk
*/

describe("example tests", () => {
  it("ensures simnet is well initialised", () => {
    expect(simnet.blockHeight).toBeDefined();
  });

  // it("shows an example", () => {
  //   const { result } = simnet.callReadOnlyFn("counter", "get-counter", [], address1);
  //   expect(result).toBeUint(0);
  // });
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
      deployer
    );
    expect(listingCreation).toBeOk(Cl.bool(true)); // (ok listing id)


    listingId = 0; // Assuming successful creation

    const {result: buyListing} = simnet.callPublicFn(
      "marketplace-fulfill",
      "fulfil-listing-ft-stx",
      [
        Cl.uint(listingId),
        Cl.principal(mockFtContract),
        Cl.uint(1000)
      ],
      address1
    )

    expect(buyListing).toBeOk(Cl.bool(true))
    
    // const { result: UpdateListing } = simnet.callPublicFn(
    //   "marketplace",
    //   "update-listing-ft",
    //   [
    //     Cl.uint(listingId),
    //     Cl.principal(mockFtContract),
    //     Cl.some(Cl.uint(200)), // new amount
    //     Cl.some(Cl.uint(75)),   // new price
    //     Cl.none()               // keep same expiry
    //   ],
    //   wallet1
    // );

    // expect(UpdateListing).toBeOk(Cl.bool(true))

    
    
    // This test assumes the listing exists and wallet1 is the maker
    // In a real scenario, you'd need to create the listing first
  })})