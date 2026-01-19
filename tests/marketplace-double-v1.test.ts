import { describe, expect, it, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = simnet.deployer;
const wallet1 = accounts.get("wallet_1")!;
const wallet2 = accounts.get("wallet_2")!;

const marketplace = "marketplace";



// const tokenA = `${deployer}.mock-token`;
const tokenA = `${deployer}.mock-token-a`;

describe("Milestone complete", () => {

  beforeEach(() => {
    simnet.setEpoch("3.0");
  });

  describe("Milestone complete 1", () => {
  
      beforeEach(() => {
        // whitelist both tokens
        simnet.callPublicFn(
          marketplace,
          "set-whitelisted",
          [Cl.principal(tokenA), Cl.bool(true), Cl.uint(4), Cl.some(Cl.uint(1000000000))],
          deployer
        );
  
        
      });
  
  
      it("Step by Step of milestone complete", () => {
  
        const listing = Cl.tuple({
          amt: Cl.uint(1000000000),
          expiry: Cl.uint(10000),
          price: Cl.uint(4),
          "payment-asset-contract": Cl.none()
        });
  
        
  
        const res1 = simnet.callPublicFn(
          marketplace,
          "list-asset-ft",
          [
            Cl.contractPrincipal(deployer, "mock-token-a"),
            Cl.contractPrincipal(deployer, "mock-token-a"),
            listing
          ],
          deployer
        );
      
  
        expect(res1.result).toBeOk(Cl.bool(true));


        const res2 = simnet.callPublicFn(
          "marketplace-fulfill",
          "reserve-listing-ft-stx",
          [
            Cl.principal(tokenA),
            Cl.contractPrincipal(deployer, "mock-token-a"),
            Cl.uint(249999998)
          ],
          wallet1
        );
      
  
        expect(res2.result).toBeOk(Cl.bool(true));


        const res3 = simnet.callReadOnlyFn(
          "marketplace",
          "get-listing-map",
          [
            Cl.principal(deployer),
            Cl.principal(tokenA),
          ],
          wallet1
        );
      
        console.log("res3: ", res3.result.value);


        const userAsset = simnet.callReadOnlyFn(
          "marketplace",
          "get-user-investment-map",
          [
            Cl.principal(wallet1),
            Cl.principal(tokenA),
          ],
          wallet1
        );
      
        console.log("user asset: ", userAsset.result.value);
        
        
        

        const res4 = simnet.callPublicFn(
          "marketplace-fulfill",
          "reserve-listing-ft-stx",
          [
            Cl.principal(tokenA),
            Cl.contractPrincipal(deployer, "mock-token-a"),
            Cl.uint(1)
          ],
          wallet1
        );
      
  
        expect(res4.result).toBeOk(Cl.bool(true));

        const res5 = simnet.callReadOnlyFn(
          "marketplace",
          "get-listing-map",
          [
            Cl.principal(deployer),
            Cl.principal(tokenA),
          ],
          wallet1
        );
      
        console.log("res5: ", res5.result.value);



        const res6 = simnet.callPublicFn(
          "marketplace",
          "claim-after-success",
          [
            Cl.contractPrincipal(deployer, "mock-token-a"),
            Cl.principal(deployer)
          ],
          wallet1
        );
      
  
        expect(res6.result).toBeOk(Cl.bool(true));

      });
  
  
    //   it("maker can update listing", () => {
  
    //     const listing = Cl.tuple({
    //       taker: Cl.none(),
    //       amt: Cl.uint(10000000),
    //       expiry: Cl.uint(10000),
    //       price: Cl.uint(5),
    //       "payment-asset-contract": Cl.some(Cl.principal(tokenB))
    //     });
  
    //     simnet.callPublicFn(
    //       marketplace,
    //       "list-asset-ft",
    //       [
    //         Cl.contractPrincipal(deployer, 'mock-token'),
    //         Cl.contractPrincipal(deployer, 'mock-token'),
    //         listing
    //       ],
    //       deployer
    //     );
  
  
    //     const res = simnet.callPublicFn(
    //       marketplace,
    //       "update-listing-ft",
    //       [
    //         Cl.contractPrincipal(deployer, 'mock-token'),
            
    //         Cl.uint(10000)
    //       ],
    //       deployer
    //     );
  
    //     expect(res.result).toBeOk(Cl.bool(true));
    //   });
  
  
    //   it("maker may cancel", () => {
  
    //     const listing = Cl.tuple({
    //       taker: Cl.none(),
    //       amt: Cl.uint(10000000),
    //       expiry: Cl.uint(20000),
    //       price: Cl.uint(3),
    //       "payment-asset-contract": Cl.some(Cl.principal(tokenB))
    //     });
  
    //     simnet.callPublicFn(
    //       marketplace,
    //       "list-asset-ft",
    //       [
    //           Cl.contractPrincipal(deployer, 'mock-token'),
    //           Cl.contractPrincipal(deployer, 'mock-token'),
    //           listing
    //       ],
    //       deployer
    //     );
  
    //     const res = simnet.callPublicFn(
    //       marketplace,
    //       "cancel-listing-ft",
    //       [
    //         Cl.contractPrincipal(deployer, 'mock-token'),
    //       ],
    //       deployer
    //     );
  
    //     expect(res.result).toBeOk(Cl.bool(true));
    //   });
  
    });

});
