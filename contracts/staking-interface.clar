(use-trait staking-ft .staking-trait.staking-trait)

(define-read-only (is-whitelisted (contract principal))
  ;; ask marketplace if contract is whitelisted
  (contract-call? .marketplace is-whitelisted contract)
)

(define-public (staking (staking-contract <staking-ft>) (amount uint) (time uint) (staker principal))
  (begin
    (is-whitelisted (contract-of staking-contract))

    ;; dynamic contract call
    (try! (contract-call? staking-contract staking amount time staker))
     (print {
        stacking-contract: staking-contract,
        staker: staker,
        block-time: time,
        amount: amount
        })
    (ok true)

  )
)



(define-public (unstaking (staking-contract <staking-ft>) (amount uint)  (unstaker principal))
  (begin
    (is-whitelisted (contract-of staking-contract))
    

    ;; dynamic contract call
    (try! (contract-call? staking-contract unstaking amount unstaker))
    (print {
        stacking-contract: staking-contract,
        unstaker: unstaker,
        amount: amount
        })
    (ok true)
  )
)

;; ---- Constants / Errors ----
(define-constant ERR-NOT-WHITELISTED (err u100)) ;; use your preferred error codes