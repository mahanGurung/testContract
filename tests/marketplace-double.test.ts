import { describe, expect, it, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = simnet.deployer;
const wallet1 = accounts.get("wallet_1")!;
const wallet2 = accounts.get("wallet_2")!;

const marketplace = "marketplace";

/**
 * Mock FT contracts you must include in simnet.toml
 * Example:
 * [[contracts]]
 * name = "mock-token-a"
 * path = "./contracts/mock-token-a.clar"
 *
 * [[contracts]]
 * name = "mock-token-b"
 * path = "./contracts/mock-token-b.clar"
 */
const tokenA = `${deployer}.mock-token`;
const tokenB = `${deployer}.mock-token-a`;

describe("Marketplace Double Contract", () => {

  beforeEach(() => {
    simnet.setEpoch("3.0");
  });

  describe("Ownership", () => {

    it("returns deployer as owner", () => {
      const { result } = simnet.callReadOnlyFn(
        marketplace,
        "get-contract-owner",
        [Cl.principal(deployer)],
        deployer
      );

      expect(result).toBeOk(Cl.bool(true));
    });

    it("allows owner to change owner", () => {
      const res = simnet.callPublicFn(
        marketplace,
        "set-contract-owner",
        [Cl.principal(wallet1)],
        deployer
      );
      expect(res.result).toBeOk(Cl.bool(true));
    });

    it("rejects non-owner owner change", () => {
      const res = simnet.callPublicFn(
        marketplace,
        "set-contract-owner",
        [Cl.principal(wallet2)],
        wallet1
      );
      expect(res.result).toBeErr(Cl.uint(2001)); // ERR_UNAUTHORISED
    });

  });


  describe("Whitelist System", () => {

    it("owner can whitelist FT contracts", () => {
      const res = simnet.callPublicFn(
        marketplace,
        "set-whitelisted",
        [Cl.principal(tokenA), Cl.bool(true), Cl.bool(false)],
        deployer
      );

      expect(res.result).toBeOk(Cl.bool(true));
    });

    it("non-owner cannot whitelist", () => {
      const res = simnet.callPublicFn(
        marketplace,
        "set-whitelisted",
        [Cl.principal(tokenB), Cl.bool(true), Cl.bool(false)],
        wallet1
      );

      expect(res.result).toBeErr(Cl.uint(2001));
    });

    it("is-whitelisted works", () => {
      simnet.callPublicFn(
        marketplace,
        "set-whitelisted",
        [Cl.principal(tokenA), Cl.bool(true), Cl.bool(false)],
        deployer
      );

      const { result } = simnet.callReadOnlyFn(
        marketplace,
        "is-whitelisted",
        [Cl.principal(tokenA)],
        deployer
      );

      expect(result).toBeBool(true);
    });

  });


  describe("Emergency Stop", () => {

    it("owner may activate emergency stop", () => {
      const res = simnet.callPublicFn(
        marketplace,
        "set-emergency-stop",
        [Cl.bool(true)],
        deployer
      );

      expect(res.result).toBeOk(Cl.bool(true));
    });

    it("read emergency status", () => {
      const { result } = simnet.callReadOnlyFn(
        marketplace,
        "get-emergency-stop",
        [],
        deployer
      );

      expect(result).toBeBool(false);
    });

  });


  describe("FT Listing", () => {

    beforeEach(() => {
      // whitelist both tokens
      simnet.callPublicFn(
        marketplace,
        "set-whitelisted",
        [Cl.principal(tokenA), Cl.bool(true), Cl.bool(false)],
        deployer
      );

      simnet.callPublicFn(
        marketplace,
        "set-whitelisted",
        [Cl.principal(tokenB), Cl.bool(true), Cl.bool(true)],
        deployer
      );
    });


    it("maker can list token A for token B", () => {

      const listing = Cl.tuple({
        taker: Cl.none(),
        amt: Cl.uint(1000),
        expiry: Cl.uint(10000),
        price: Cl.uint(5),
        "payment-asset-contract": Cl.some(Cl.contractPrincipal(deployer, "mock-token-a"))
      });

      

      const res = simnet.callPublicFn(
        marketplace,
        "list-asset-ft",
        [
          Cl.contractPrincipal(deployer, 'mock-token'),
          Cl.contractPrincipal(deployer, 'mock-token'),
          listing
        ],
        deployer
      );
    

      expect(res.result).toBeOk(Cl.bool(true));
    });


    it("maker can update listing", () => {

      const listing = Cl.tuple({
        taker: Cl.none(),
        amt: Cl.uint(10000000),
        expiry: Cl.uint(10000),
        price: Cl.uint(5),
        "payment-asset-contract": Cl.some(Cl.principal(tokenB))
      });

      simnet.callPublicFn(
        marketplace,
        "list-asset-ft",
        [
          Cl.contractPrincipal(deployer, 'mock-token'),
          Cl.contractPrincipal(deployer, 'mock-token'),
          listing
        ],
        deployer
      );


      const res = simnet.callPublicFn(
        marketplace,
        "update-listing-ft",
        [
          Cl.contractPrincipal(deployer, 'mock-token'),
          Cl.some(Cl.uint(3000000)),
          Cl.none(),
          Cl.none()
        ],
        deployer
      );

      expect(res.result).toBeOk(Cl.bool(true));
    });


    it("maker may cancel", () => {

      const listing = Cl.tuple({
        taker: Cl.none(),
        amt: Cl.uint(1000),
        expiry: Cl.uint(20000),
        price: Cl.uint(3),
        "payment-asset-contract": Cl.some(Cl.principal(tokenB))
      });

      simnet.callPublicFn(
        marketplace,
        "list-asset-ft",
        [
            Cl.contractPrincipal(deployer, 'mock-token'),
            Cl.contractPrincipal(deployer, 'mock-token'),
            listing
        ],
        deployer
      );

      const res = simnet.callPublicFn(
        marketplace,
        "cancel-listing-ft",
        [
          Cl.contractPrincipal(deployer, 'mock-token'),
        ],
        deployer
      );

      expect(res.result).toBeOk(Cl.bool(true));
    });

  });


  describe("Fulfillment", () => {

    beforeEach(() => {
      simnet.callPublicFn(marketplace, "set-whitelisted", [Cl.principal(tokenA), Cl.bool(true), Cl.bool(false)], deployer);
      simnet.callPublicFn(marketplace, "set-whitelisted", [Cl.principal(tokenB), Cl.bool(true), Cl.bool(true)], deployer);
    });

    it("buyer can fulfil using FT", () => {

      const listing = Cl.tuple({
        taker: Cl.none(),
        amt: Cl.uint(10000000),
        expiry: Cl.uint(5000),
        price: Cl.uint(2),
        "payment-asset-contract": Cl.some(Cl.principal(tokenB))
      });

      simnet.callPublicFn(
        marketplace,
        "list-asset-ft",
        [
            Cl.contractPrincipal(deployer, 'mock-token'),
            Cl.contractPrincipal(deployer, 'mock-token'),
            listing
        ],
        deployer
      );

      const result = simnet.callPublicFn(
        "marketplace-fulfill",
        "fulfil-ft-listing-ft",
        [
            Cl.contractPrincipal(deployer, 'mock-token'),
            Cl.contractPrincipal(deployer, 'mock-token'),
            Cl.contractPrincipal(deployer, 'mock-token-a'),
            Cl.uint(3000000)
        ],
        wallet2
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });


    it("buyer can fulfil with STX", () => {

      const listing = Cl.tuple({
        taker: Cl.none(),
        amt: Cl.uint(10000000),
        expiry: Cl.uint(5000),
        price: Cl.uint(10),
        "payment-asset-contract": Cl.none()
      });

      simnet.callPublicFn(
        marketplace,
        "list-asset-ft",
        [
            Cl.contractPrincipal(deployer, 'mock-token'),
            Cl.contractPrincipal(deployer, 'mock-token'),
            listing
        ],
        deployer
      );

      const res = simnet.callPublicFn(
        "marketplace-fulfill",
        "fulfil-listing-ft-stx",
        [
          Cl.contractPrincipal(deployer, 'mock-token'),
          Cl.contractPrincipal(deployer, 'mock-token'),
          Cl.uint(2000000)
        ],
        wallet2
      );

      expect(res.result).toBeOk(Cl.bool(true));
    });

  });


  describe("Fees", () => {

    it("owner can update fees", () => {
      const res = simnet.callPublicFn(
        marketplace,
        "set-transaction-fee-bps",
        [Cl.uint(750)],
        deployer
      );

      expect(res.result).toBeOk(Cl.bool(true));
    });

    it("calculate-fee-for-amount works", () => {
      const { result } = simnet.callReadOnlyFn(
        marketplace,
        "calculate-fee-for-amount",
        [Cl.uint(10000)],
        deployer
      );

      expect(result).toBeUint(500); // default 5%
    });

  });

});
